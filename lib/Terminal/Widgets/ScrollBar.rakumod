# ABSTRACT: Roles and classes for scrollbars

use Terminal::Widgets::Events;
use Terminal::Widgets::Widget;
use Terminal::Widgets::Scrollable;

subset ScrollTarget where Str | Terminal::Widgets::Scrollable;


#| Role for scrollbars of any orientation
role Terminal::Widgets::Scrollbar {
    has ScrollTarget:D $.scroll-target is required;

    has Bool:D $.show-end-arrows      = True;
    has UInt:D $.end-arrow-scroll-inc = 0;
    has UInt:D $.bar-click-scroll-inc = 0;

    has %!glyphs = self.scrollbar-glyphs;

    # Required methods
    method update-bar-position() { ... }

    #| Choose glyphs appropriate to terminal capabilities
    method scrollbar-glyphs($caps = self.terminal.caps) {
        my constant %ASCII =
            up     => '^',
            bar    => ':',
            down   => 'v',
            left   => chr(0x3c), # <
            right  => '>',
            handle => '#';

        my constant %WGL4R = |%ASCII,
            up     => '▲',
            bar    => '▒',
            down   => '▼',
            handle => '█';

        my constant %WGL4  = |%WGL4R,
            left   => '◄',
            right  => '►';

        my constant %Uni1  = |%WGL4,
            left   => '◀',
            right  => '▶';

        my constant %glyphs = :%ASCII, :%WGL4R, :%WGL4, :%Uni1;

        $caps.best-symbol-choice(%glyphs);
    }

    #| Handle LayoutBuilt event by resolving scroll-target
    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, AtTarget) {
        $!scroll-target = self.toplevel.by-id{$!scroll-target}
            if $!scroll-target ~~ Str:D;
    }
}


#| A horizontal scrollbar
class Terminal::Widgets::HScrollBar
   is Terminal::Widgets::Widget
 does Terminal::Widgets::Scrollbar {
    submethod TWEAK() {
        $!end-arrow-scroll-inc ||= 8;
        $!bar-click-scroll-inc ||= self.content-width;
    }

    method arrow-left-scroll() {
        $.scroll-target.change-x-scroll(-$.end-arrow-scroll-inc);
        self.update-bar-position;
    }

    method arrow-right-scroll() {
        $.scroll-target.change-x-scroll(+$.end-arrow-scroll-inc);
        self.update-bar-position;
    }

    method bar-left-scroll() {
        $.scroll-target.change-x-scroll(-$.bar-click-scroll-inc);
        self.update-bar-position;
    }

    method bar-right-scroll() {
        $.scroll-target.change-x-scroll(+$.bar-click-scroll-inc);
        self.update-bar-position;
    }

    method home-scroll() {
        $.scroll-target.set-x-scroll(0);
        self.update-bar-position;
    }

    method end-scroll() {
        $.scroll-target.set-x-scroll($.scroll-target.x-max);
        self.update-bar-position;
    }

    method update-bar-position() {
        # Compute left and right column of handle on scrollbar,
        # safely accounting for several possible edge cases
        my $width  = self.content-width - 2 * $.show-end-arrows;
        my $max    = $.target.x-max || 1;
        my $scroll = $.target.x-scroll min $max;
        my $end    = 0 max ($max min $scroll + $.target.content-width - 1);
        my $right  = floor(  $width * $end    / $max);
        my $left   = ceiling($width * $scroll / $max) min $right;

        # Actually draw updated bar and handle
        my $layout = self.layout.computed;
        my $y      =           $layout.top-correction;
        my $x1     =           $layout.left-correction  + $.show-end-arrows;
        my $x2     = $.w - 1 - $layout.right-correction - $.show-end-arrows;
        $.grid.change-cell($_, $y, %.glyphs<bar>)    for $x1   .. $x2;
        $.grid.change-cell($_, $y, %.glyphs<handle>) for $left .. $right;

        # Draw optional end arrows
        if $.show-end-arrows {
            $.grid.change-cell($x1 - 1, $y, %.glyphs<left>);
            $.grid.change-cell($x2 + 1, $y, %.glyphs<right>);
        }

        # Everything was changed
        self.set-all-dirty;
        self.composite;
    }
}


#| A vertical scrollbar
class Terminal::Widgets::VScrollBar
   is Terminal::Widgets::Widget
 does Terminal::Widgets::Scrollbar {
    submethod TWEAK() {
        $!end-arrow-scroll-inc ||= 4;
        $!bar-click-scroll-inc ||= self.content-height;
    }

    method arrow-up-scroll() {
        $.scroll-target.change-y-scroll(-$.end-arrow-scroll-inc);
        self.update-bar-position;
    }

    method arrow-down-scroll() {
        $.scroll-target.change-y-scroll(+$.end-arrow-scroll-inc);
        self.update-bar-position;
    }

    method bar-up-scroll() {
        $.scroll-target.change-y-scroll(-$.bar-click-scroll-inc);
        self.update-bar-position;
    }

    method bar-down-scroll() {
        $.scroll-target.change-y-scroll(+$.bar-click-scroll-inc);
        self.update-bar-position;
    }

    method home-scroll() {
        $.scroll-target.set-y-scroll(0);
        self.update-bar-position;
    }

    method end-scroll() {
        $.scroll-target.set-y-scroll($.scroll-target.y-max);
        self.update-bar-position;
    }

    method update-bar-position() {
        # Compute top and bottom row of handle on scrollbar,
        # safely accounting for several possible edge cases
        my $height = self.content-height - 2 * $.show-end-arrows;
        my $max    = $.target.y-max || 1;
        my $scroll = $.target.y-scroll min $max;
        my $end    = 0 max ($max min $scroll + $.target.content-height - 1);
        my $bottom = floor(  $height * $end    / $max);
        my $top    = ceiling($height * $scroll / $max) min $bottom;

        # Actually draw updated bar and handle
        my $layout = self.layout.computed;
        my $x      =           $layout.left-correction;
        my $y1     =           $layout.top-correction    + $.show-end-arrows;
        my $y2     = $.h - 1 - $layout.bottom-correction - $.show-end-arrows;
        $.grid.change-cell($x, $_, %.glyphs<bar>)    for $y1  .. $y2;
        $.grid.change-cell($x, $_, %.glyphs<handle>) for $top .. $bottom;

        # Draw optional end arrows
        if $.show-end-arrows {
            $.grid.change-cell($x, $y1 - 1, %.glyphs<up>);
            $.grid.change-cell($x, $y2 + 1, %.glyphs<down>);
        }

        # Everything was changed
        self.set-all-dirty;
        self.composite;
    }
}
