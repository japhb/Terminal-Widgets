# ABSTRACT: Common role for scrollable widgets

use Terminal::Widgets::Events;


#| Common role for scrollable widgets
role Terminal::Widgets::Scrollable {
    has UInt:D $.x-scroll = 0;
    has UInt:D $.y-scroll = 0;
    has UInt:D $.x-max    = self.content-width;
    has UInt:D $.y-max    = self.content-height;
    has Bool:D $!scrolled = False;
    has %.scrollbars is SetHash;

    method refresh-for-scroll() {
        if $!scrolled {
            .full-refresh for %.scrollbars.keys;
            self.full-refresh;
            $!scrolled = False;
        }
    }

    # NOTE: If changing both x-max and x-scroll, call this one first!
    method set-x-max(UInt:D $x-max) {
        if  $!x-max != $x-max {
            $!x-max  = $x-max;
            $!scrolled = True;
        }
    }

    # NOTE: If changing both y-max and y-scroll, call this one first!
    method set-y-max(UInt:D $y-max) {
        if  $!y-max != $y-max {
            $!y-max  = $y-max;
            $!scrolled = True;
        }
    }

    method set-x-scroll(Int:D $x-scroll) {
        # Refresh widget if scroll position changed
        my $new  = 0 max ($x-scroll min $!x-max);
        if $new != $!x-scroll {
            $!x-scroll = $new;
            $!scrolled = True;
        }
    }

    method set-y-scroll(Int:D $y-scroll) {
        # Refresh widget if scroll position changed
        my $new  = 0 max ($y-scroll min $!y-max);
        if $new != $!y-scroll {
            $!y-scroll = $new;
            $!scrolled = True;
        }
    }

    method change-x-scroll(Int:D $x-change) {
        self.set-x-scroll($!x-scroll + $x-change);
    }

    method change-y-scroll(Int:D $y-change) {
        self.set-y-scroll($!y-scroll + $y-change);
    }

    method ensure-x-span-visible(UInt:D $x1, UInt:D $x2) {
        # If widget can show entirety of X span at once, ensure that happens;
        # otherwise, show as much as possible of the X span, preferring to
        # show the left edge at $x1.
        my $old-right = $!x-max min $!x-scroll + self.content-width - 1;
        my $new-right = $!x-max min $x2;
        my $new-x     = $x1 min $!x-scroll + (0 max $new-right - $old-right);
        self.set-x-scroll($new-x);
    }

    method ensure-y-span-visible(UInt:D $y1, UInt:D $y2) {
        # If widget can show entirety of Y span at once, ensure that happens;
        # otherwise, show as much as possible of the Y span, preferring to
        # show the top edge at $y1.
        my $old-bottom = $!y-max min $!y-scroll + self.content-height - 1;
        my $new-bottom = $!y-max min $y2;
        my $new-y      = $y1 min $!y-scroll + (0 max $new-bottom - $old-bottom);
        self.set-y-scroll($new-y);
    }

    method ensure-rect-visible(UInt:D $x, UInt:D $y, UInt:D $w, UInt:D $h) {
        # If widget can show entirety of rect at once, ensure that happens;
        # otherwise, show as much as possible of the rect, preferring to
        # show the upper left corner of the rect at ($x, $y).
        self.ensure-x-span-visible($x, $x + (0 max $w - 1));
        self.ensure-y-span-visible($y, $y + (0 max $h - 1));
    }

    #| Handle mouse wheel events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where { .mouse.pressed &&
                                             .mouse.button  == 4|5|6|7 }, AtTarget) {
        # Take focus even if wheeled over framing instead of content area
        self.toplevel.focus-on(self);

        # Process wheel up/down/left/right
        given $event.mouse.button {
            when 4 { self.change-y-scroll: -4 }
            when 5 { self.change-y-scroll: +4 }
            when 6 { self.change-x-scroll: -8 }
            when 7 { self.change-x-scroll: +8 }
        }

        self.refresh-for-scroll;
    }
}
