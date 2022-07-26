# ABSTRACT: Wrapper of Terminal::Print::Widget with EventHandling and Animation hooks

use Terminal::Print::Widget;
use Terminal::Print::Animated;

use Terminal::Widgets::Events;
use Terminal::Widgets::Layout;


#| Wrapper of Terminal::Print::FrameInfo
class Terminal::Widgets::FrameInfo is Terminal::Print::FrameInfo { }


#| Extension to Terminal::Print::Widget, Animated and with EventHandling
class Terminal::Widgets::Widget
   is Terminal::Print::Widget
 does Terminal::Print::Animated
 does Terminal::Widgets::Events::EventHandling {
    #| Dynamic layout node associated with this widget
    has Terminal::Widgets::Layout::Dynamic $.layout;

    has Str:D $.id = ''; #= String ID (must be unique within TopLevel *if* non-empty)
    has Int:D $.z  = 0;  #= Z offset from parent; default = in-plane

    has Int $.x-offset;  #= Cumulative X offset from screen root, + = right
    has Int $.y-offset;  #= Cumulative Y offset from screen root, + = down
    has Int $.z-offset;  #= Cumulative Z offset from screen root, + = nearer


    #| Bootstrapping: Setting TopLevel's layout
    method set-layout($!layout) { }

    #| Non-TopLevel Widgets cannot be the terminal's current-toplevel
    method is-current-toplevel(--> False) { }

    #| Find the nearest ancestor (or self) that doesn't have a Widget parent,
    #| and thus should be the nearest "toplevel" (without use'ing TopLevel)
    method toplevel() {
        my $toplevel = self;
        $toplevel .= parent while $toplevel.parent ~~ Terminal::Widgets::Widget;
        $toplevel
    }

    #| Determine default focus point within widget tree
    method default-focus() {
        if $.focused-child {
            $.focused-child.default-focus
        }
        else {
            my $focusable = @.children.first(Terminal::Widgets::Events::EventHandling);
            $focusable ?? $focusable.default-focus() !! self
        }
    }

    #| Gain focus and ensure that proper child is focused
    method gain-focus(Bool:D :$redraw = True) {
        # note "default-focus is {self.default-focus.^name}";
        self.toplevel.focus-on(self.default-focus, :$redraw);
    }

    #| Find first matching widget in this subtree, starting with self
    method first-widget($matcher = { True }) {
        self ~~ $matcher ?? self !! @.children.first(*.first-widget($matcher))
    }

    #| Find last matching widget in this subtree, ending with self
    method last-widget($matcher = { True }) {
        @.children.reverse.first(*.last-widget($matcher))
        // (self ~~ $matcher ?? self !! Nil)
    }

    #| Find next matching widget after self
    method next-widget($matcher = { True }) {
        if $.parent {
            # Check following siblings
            my $found-self = False;
            for $.parent.children {
                if $_ === self {
                    $found-self = True;
                }
                elsif $found-self {
                    .return with .first-widget($matcher);
                }
            }

            # No luck with siblings, go to cousins
            $.parent.next-widget($matcher)
        }
        else { Nil }
    }

    #| Find previous matching widget before self
    method prev-widget($matcher = { True }) {
        if $.parent {
            # Check leading siblings
            my $found-self = False;
            for $.parent.children.reverse {
                if $_ === self {
                    $found-self = True;
                }
                elsif $found-self {
                    .return with .last-widget($matcher);
                }
            }

            # No luck with siblings, go to cousins
            $.parent.prev-widget($matcher)
        }
        else { Nil }
    }

    #| Update computed upper-left coordinate offsets for self and children
    method recalc-coord-offsets(Int:D $parent-x, Int:D $parent-y, Int:D $parent-z) {
        # Recompute offsets for self
        $!x-offset = $.x + $parent-x;
        $!y-offset = $.y + $parent-y;
        $!z-offset = $.z + $parent-z;

        # Ask children to recompute their offsets
        .recalc-coord-offsets($!x-offset, $!y-offset, $!z-offset) for @.children;
    }

    #| After moving, call recalc-coord-offsets on self
    method move-to($x, $y, $!z = $.z) {
        callwith($x, $y);
        if $.parent {
            self.recalc-coord-offsets($.parent.x-offset,
                                      $.parent.y-offset,
                                      $.parent.z-offset);
        }
        else {
            self.recalc-coord-offsets(0, 0, 0);
        }
    }

    #| Resize or move this widget
    method update-geometry( Int:D :$x = $.x,  Int:D :$y = $.y, Int:D :$z = $.z,
                           UInt:D :$w = $.w, UInt:D :$h = $.h) {
        if $x != $.x || $y != $.y || $z != $.z {
            self.move-to($x, $y, $z);
        }

        if $w != $.w || $h != $.h {
            # XXXX: Does not currently save old contents at all
            my $new-grid = $.grid.WHAT.new($w, $h);
            self.replace-grid($new-grid);
        }
    }

    #| Composite children with painter's algorithm (in Z order, back to front)
    method draw-frame() {
        # XXXX: Cache the sorted order?
        .composite for @.children.sort({ .?z // 0 });
    }
}
