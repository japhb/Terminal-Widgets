# ABSTRACT: Wrapper of Terminal::Print::Widget with EventHandling added

use Terminal::Print::Widget;

use Terminal::Widgets::Events;


#| Extension to Terminal::Print::Widget, with EventHandling
class Terminal::Widgets::Widget
   is Terminal::Print::Widget
 does Terminal::Widgets::Events::EventHandling {
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
}
