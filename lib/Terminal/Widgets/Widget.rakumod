# ABSTRACT: Wrapper of Terminal::Print::Widget with EventHandling added

use Terminal::Print::Widget;

use Terminal::Widgets::Events;
use Terminal::Widgets::Layout;


#| Extension to Terminal::Print::Widget, with EventHandling
class Terminal::Widgets::Widget
   is Terminal::Print::Widget
 does Terminal::Widgets::Events::EventHandling {
    #| Dynamic layout node associated with this widget
    has Terminal::Widgets::Layout::Dynamic $.layout;

    has Int $.x-offset;  #= Cumulative X offset from screen root
    has Int $.y-offset;  #= Cumulative Y offset from screen root

    #| Update computed upper-left coordinate offsets for self and children
    method recalc-coord-offsets(Int:D $parent-x, Int:D $parent-y) {
        # Recompute offsets for self
        $!x-offset = $.x + $parent-x;
        $!y-offset = $.y + $parent-y;

        # Ask children to recompute their offsets
        .recalc-coord-offsets($!x-offset, $!y-offset) for @.children;
    }

    #| Resize or move this widget
    method update-geometry( Int:D :$x = $.x,  Int:D :$y = $.y,
                           UInt:D :$w = $.w, UInt:D :$h = $.h) {
        if $x != $.x || $y != $.y {
            self.move-to($x, $y);
        }

        if $w != $.w || $h != $.h {
            # XXXX: Does not currently save old contents at all
            # XXXX: What if the old grid was $*TERMINAL.current-grid ?
            my $new-grid = $.grid.WHAT.new($w, $h);
            self.replace-grid($new-grid);
        }

        # XXXX: Redraw?

        self
    }
}
