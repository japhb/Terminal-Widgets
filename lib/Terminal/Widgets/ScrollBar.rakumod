# ABSTRACT: Roles and classes for scrollbars

use Terminal::Widgets::Events;
use Terminal::Widgets::Widget;
use Terminal::Widgets::Focusable;
use Terminal::Widgets::Themable;
use Terminal::Widgets::Scrollable;

subset ScrollTarget where Str | Terminal::Widgets::Scrollable;


#| Role for scrollbars of any orientation
role Terminal::Widgets::Scrollbar
does Terminal::Widgets::Themable
does Terminal::Widgets::Focusable {
    has ScrollTarget:D $.scroll-target is required;

    has Bool:D $.show-end-arrows = True;

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
    method h-arrow-scroll-inc() {
        my $ui-prefs = self.terminal.ui-prefs;

                $ui-prefs<mouse-wheel-horizontal-speed>
        || 2 * ($ui-prefs<mouse-wheel-vertical-speed> || 4)
    }

    method h-bar-scroll-inc() {
        $.scroll-target.content-width
    }

    method arrow-left-scroll() {
        $.scroll-target.change-x-scroll(-self.h-arrow-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method arrow-right-scroll() {
        $.scroll-target.change-x-scroll(+self.h-arrow-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method bar-left-scroll() {
        $.scroll-target.change-x-scroll(-self.h-bar-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method bar-right-scroll() {
        $.scroll-target.change-x-scroll(+self.h-bar-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method home-scroll() {
        $.scroll-target.set-x-scroll(0);
        $.scroll-target.refresh-for-scroll;
    }

    method end-scroll() {
        $.scroll-target.set-x-scroll($.scroll-target.x-max);
        $.scroll-target.refresh-for-scroll;
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

        # Get current color according to theme states, fading the
        # scrollbar if it's unneeded (everything visible, scroll = 0)
        my $needed   = $scroll || $end < $max;
        my $color    = self.current-color;
           $color   ~= ' faint' unless $needed;
        my $g-bar    = $.grid.cell(%!glyphs<bar>,    $color);
        my $g-handle = $.grid.cell(%!glyphs<handle>, $color);
        my $g-left   = $.grid.cell(%!glyphs<left>,   $color);
        my $g-right  = $.grid.cell(%!glyphs<right>,  $color);

        # Actually draw updated bar and handle
        my $y  =           $layout.top-correction;
        my $x1 =           $layout.left-correction  + $.show-end-arrows;
        my $x2 = $.w - 1 - $layout.right-correction - $.show-end-arrows;
        $.grid.change-cell($_, $y, $g-bar)    for $x1   .. $x2;
        $.grid.change-cell($_, $y, $g-handle) for $left .. $right;

        # Draw optional end arrows
        if $.show-end-arrows {
            $.grid.change-cell($x1 - 1, $y, $g-left);
            $.grid.change-cell($x2 + 1, $y, $g-right);
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
            Ctrl-I           => 'focus-next',    # Tab
            ShiftTab         => 'focus-prev',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'arrow-left-scroll'  { self.arrow-left-scroll  }
            when 'arrow-right-scroll' { self.arrow-right-scroll }
            when 'bar-left-scroll'    { self.bar-left-scroll    }
            when 'bar-right-scroll'   { self.bar-right-scroll   }
            when 'home-scroll'        { self.home-scroll        }
            when 'end-scroll'         { self.end-scroll         }
            when 'focus-next'         { self.focus-next }
            when 'focus-prev'         { self.focus-prev }
        }
    }

    #| Handle mouse wheel events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where { .mouse.pressed &&
                                             .mouse.button  == 6|7 }, AtTarget) {
        # Take focus even if wheeled over framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled, process wheel left/right
        if $.enabled {
            given $event.mouse.button {
                when 6 { self.arrow-left-scroll  }
                when 7 { self.arrow-right-scroll }
            }
        }
        else {
            # Refresh even not enabled because of focus state change
            self.full-refresh;
        }
    }

    #| Handle mouse click events
    #  XXXX: Handle drag events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Take focus even if clicked on framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled and within content area, process click
        if $.enabled {
            my ($x, $y, $w, $h) = $event.relative-to-content-area(self);

            if 0 <= $x < $w && 0 <= $y < $h {
                my $end = $w - 1;

                # Handle end arrows if any
                if $.show-end-arrows {
                    if $x == 0 {
                        self.arrow-left-scroll;
                        return;
                    }
                    elsif $x == $end {
                        self.arrow-right-scroll;
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
                return;
            }
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }
}


#| A vertical scrollbar
class Terminal::Widgets::VScrollBar
   is Terminal::Widgets::Widget
 does Terminal::Widgets::Scrollbar {
    method v-arrow-scroll-inc() {
        self.terminal.ui-prefs<mouse-wheel-vertical-speed> || 4
    }

    method v-bar-scroll-inc() {
        $.scroll-target.content-height
    }

    method arrow-up-scroll() {
        $.scroll-target.change-y-scroll(-self.v-arrow-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method arrow-down-scroll() {
        $.scroll-target.change-y-scroll(+self.v-arrow-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method bar-up-scroll() {
        $.scroll-target.change-y-scroll(-self.v-bar-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method bar-down-scroll() {
        $.scroll-target.change-y-scroll(+self.v-bar-scroll-inc);
        $.scroll-target.refresh-for-scroll;
    }

    method home-scroll() {
        $.scroll-target.set-y-scroll(0);
        $.scroll-target.refresh-for-scroll;
    }

    method end-scroll() {
        $.scroll-target.set-y-scroll($.scroll-target.y-max);
        $.scroll-target.refresh-for-scroll;
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

        # Get current color according to theme states, fading the
        # scrollbar if it's unneeded (everything visible, scroll = 0)
        my $needed   = $scroll || $end < $max;
        my $color    = self.current-color;
           $color   ~= ' faint' unless $needed;
        my $g-bar    = $.grid.cell(%!glyphs<bar>,    $color);
        my $g-handle = $.grid.cell(%!glyphs<handle>, $color);
        my $g-up     = $.grid.cell(%!glyphs<up>,     $color);
        my $g-down   = $.grid.cell(%!glyphs<down>,   $color);

        # Actually draw updated bar and handle
        my $x      =           $layout.left-correction;
        my $y1     =           $layout.top-correction    + $.show-end-arrows;
        my $y2     = $.h - 1 - $layout.bottom-correction - $.show-end-arrows;
        $.grid.change-cell($x, $_, $g-bar)    for $y1  .. $y2;
        $.grid.change-cell($x, $_, $g-handle) for $top .. $bottom;

        # Draw optional end arrows
        if $.show-end-arrows {
            $.grid.change-cell($x, $y1 - 1, $g-up);
            $.grid.change-cell($x, $y2 + 1, $g-down);
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
            Ctrl-I          => 'focus-next',    # Tab
            ShiftTab        => 'focus-prev',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'arrow-up-scroll'   { self.arrow-up-scroll   }
            when 'arrow-down-scroll' { self.arrow-down-scroll }
            when 'bar-up-scroll'     { self.bar-up-scroll     }
            when 'bar-down-scroll'   { self.bar-down-scroll   }
            when 'home-scroll'       { self.home-scroll       }
            when 'end-scroll'        { self.end-scroll        }
            when 'focus-next'        { self.focus-next }
            when 'focus-prev'        { self.focus-prev }
        }
    }

    #| Handle mouse wheel events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where { .mouse.pressed &&
                                             .mouse.button  == 4|5 }, AtTarget) {
        # Take focus even if wheeled over framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled, process wheel up/down
        if $.enabled {
            given $event.mouse.button {
                when 4 { self.arrow-up-scroll   }
                when 5 { self.arrow-down-scroll }
            }
        }
        else {
            # Refresh even not enabled because of focus state change
            self.full-refresh;
        }
    }

    #| Handle mouse click events
    #  XXXX: Handle drag events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Take focus even if clicked on framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled and within content area, process click
        if $.enabled {
            my ($x, $y, $w, $h) = $event.relative-to-content-area(self);

            if 0 <= $x < $w && 0 <= $y < $h {
                my $end = $h - 1;

                # Handle end arrows if any
                if $.show-end-arrows {
                    if $y == 0 {
                        self.arrow-up-scroll;
                        return;
                    }
                    elsif $y == $end {
                        self.arrow-down-scroll;
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
                return;
            }
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }
}
