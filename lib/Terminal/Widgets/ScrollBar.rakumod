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
        $!scroll-target.scrollbars.set(self);
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
    }

    method arrow-right-scroll() {
        $.scroll-target.change-x-scroll(+$.end-arrow-scroll-inc);
    }

    method bar-left-scroll() {
        $.scroll-target.change-x-scroll(-$.bar-click-scroll-inc);
    }

    method bar-right-scroll() {
        $.scroll-target.change-x-scroll(+$.bar-click-scroll-inc);
    }

    method home-scroll() {
        $.scroll-target.set-x-scroll(0);
    }

    method end-scroll() {
        $.scroll-target.set-x-scroll($.scroll-target.x-max);
    }

    method draw-content() {
        # Compute left and right column of handle on scrollbar,
        # safely accounting for several possible edge cases
        my $layout = self.layout.computed;
        my $width  = self.content-width - 2 * $.show-end-arrows;
        my $max    = $.scroll-target.x-max || 1;
        my $scroll = $.scroll-target.x-scroll min $max;
        my $end    = $max min $scroll + $.scroll-target.content-width;
        my $right  = floor(  ($width - 1) * $end    / $max);
        my $left   = ceiling(($width - 1) * $scroll / $max) min $right;
        $right    += $layout.left-correction + $.show-end-arrows;
        $left     += $layout.left-correction + $.show-end-arrows;

        # Actually draw updated bar and handle
        my $y      =           $layout.top-correction;
        my $x1     =           $layout.left-correction  + $.show-end-arrows;
        my $x2     = $.w - 1 - $layout.right-correction - $.show-end-arrows;
        $.grid.change-cell($_, $y, %!glyphs<bar>)    for $x1   .. $x2;
        $.grid.change-cell($_, $y, %!glyphs<handle>) for $left .. $right;

        # Draw optional end arrows
        if $.show-end-arrows {
            $.grid.change-cell($x1 - 1, $y, %!glyphs<left>);
            $.grid.change-cell($x2 + 1, $y, %!glyphs<right>);
        }
    }

    #| Handle keyboard events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorLeft       => 'arrow-left-scroll',
            CursorRight      => 'arrow-right-scroll',
            Ctrl-CursorLeft  => 'bar-left-scroll',
            Ctrl-CursorRight => 'bar-right-scroll',
            Home             => 'home-scroll',
            End              => 'end-scroll',
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'arrow-left-scroll'  { self.arrow-left-scroll  }
            when 'arrow-right-scroll' { self.arrow-right-scroll }
            when 'bar-left-scroll'    { self.bar-left-scroll    }
            when 'bar-right-scroll'   { self.bar-right-scroll   }
            when 'home-scroll'        { self.home-scroll        }
            when 'end-scroll'         { self.end-scroll         }
        }
    }

    #| Handle mouse events
    #  XXXX: Handle drag events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Determine relative click location and bounds
        my $layout = $.layout.computed;
        my $x      = 0 max $event.relative-to(self)[0] - $layout.left-correction;
        my $end    = 0 max $.w - 1 - $layout.right-correction;

        # Handle end arrows if any
        if $.show-end-arrows {
            if $x == 0 {
                self.arrow-left-scroll;
                $.scroll-target.refresh-for-scroll;
                return;
            }
            elsif $x == $end {
                self.arrow-right-scroll;
                $.scroll-target.refresh-for-scroll;
                return;
            }
            else {
                $end -= 2;
                $x--;
            }
        }

        # Handle bar events
        my $scroll = floor($.scroll-target.x-max * $x / ($end max 1));
        $.scroll-target.set-x-scroll($scroll);
        $.scroll-target.refresh-for-scroll;
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
    }

    method arrow-down-scroll() {
        $.scroll-target.change-y-scroll(+$.end-arrow-scroll-inc);
    }

    method bar-up-scroll() {
        $.scroll-target.change-y-scroll(-$.bar-click-scroll-inc);
    }

    method bar-down-scroll() {
        $.scroll-target.change-y-scroll(+$.bar-click-scroll-inc);
    }

    method home-scroll() {
        $.scroll-target.set-y-scroll(0);
    }

    method end-scroll() {
        $.scroll-target.set-y-scroll($.scroll-target.y-max);
    }

    method draw-content() {
        # Compute top and bottom row of handle on scrollbar,
        # safely accounting for several possible edge cases
        my $layout = self.layout.computed;
        my $height = self.content-height - 2 * $.show-end-arrows;
        my $max    = $.scroll-target.y-max || 1;
        my $scroll = $.scroll-target.y-scroll min $max;
        my $end    = $max min $scroll + $.scroll-target.content-height;
        my $bottom = floor(  ($height - 1) * $end    / $max);
        my $top    = ceiling(($height - 1) * $scroll / $max) min $bottom;
        $bottom   += $layout.top-correction + $.show-end-arrows;
        $top      += $layout.top-correction + $.show-end-arrows;

        # Actually draw updated bar and handle
        my $x      =           $layout.left-correction;
        my $y1     =           $layout.top-correction    + $.show-end-arrows;
        my $y2     = $.h - 1 - $layout.bottom-correction - $.show-end-arrows;
        $.grid.change-cell($x, $_, %!glyphs<bar>)    for $y1  .. $y2;
        $.grid.change-cell($x, $_, %!glyphs<handle>) for $top .. $bottom;

        # Draw optional end arrows
        if $.show-end-arrows {
            $.grid.change-cell($x, $y1 - 1, %!glyphs<up>);
            $.grid.change-cell($x, $y2 + 1, %!glyphs<down>);
        }
    }

    #| Handle keyboard events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorUp        => 'arrow-up-scroll',
            CursorDown      => 'arrow-down-scroll',
            Ctrl-CursorUp   => 'bar-up-scroll',
            Ctrl-CursorDown => 'bar-down-scroll',
            Home            => 'home-scroll',
            End             => 'end-scroll',
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'arrow-up-scroll'   { self.arrow-up-scroll   }
            when 'arrow-down-scroll' { self.arrow-down-scroll }
            when 'bar-up-scroll'     { self.bar-up-scroll     }
            when 'bar-down-scroll'   { self.bar-down-scroll   }
            when 'home-scroll'       { self.home-scroll       }
            when 'end-scroll'        { self.end-scroll        }
        }
    }

    #| Handle mouse events
    #  XXXX: Handle drag events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Determine relative click location and bounds
        my $layout = $.layout.computed;
        my $y      = 0 max $event.relative-to(self)[1] - $layout.top-correction;
        my $end    = 0 max $.h - 1 - $layout.bottom-correction;

        # Handle end arrows if any
        if $.show-end-arrows {
            if $y == 0 {
                self.arrow-up-scroll;
                $.scroll-target.refresh-for-scroll;
                return;
            }
            elsif $y == $end {
                self.arrow-down-scroll;
                $.scroll-target.refresh-for-scroll;
                return;
            }
            else {
                $end -= 2;
                $y--;
            }
        }

        # Handle bar events
        my $scroll = floor($.scroll-target.y-max * $y / ($end max 1));
        $.scroll-target.set-y-scroll($scroll);
        $.scroll-target.refresh-for-scroll;
    }
}
