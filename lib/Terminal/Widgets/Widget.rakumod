# ABSTRACT: Wrapper of Terminal::Print::Widget with EventHandling and Animation hooks

use Terminal::Print::Widget;
use Terminal::Print::Animated;
use Terminal::Print::BoxDrawing;

use Terminal::Widgets::Events;
use Terminal::Widgets::Layout;


#| Wrapper of Terminal::Print::FrameInfo
class Terminal::Widgets::FrameInfo is Terminal::Print::FrameInfo { }


#| Role for dirty area handling
role Terminal::Widgets::DirtyAreas {
    has @!dirty-rects;   #= Dirty rectangles that must be composited into parent
    has Bool:D $!all-dirty   = True;  #= Whether entire widget is dirty (optimization)
    has Lock:D $!dirty-lock .= new;   #= Lock on modifications to dirty list/flag

    #| Check if parent exists and is dirtyable
    method parent-dirtyable() {
        $.parent && $.parent ~~ Terminal::Widgets::DirtyAreas
    }

    #| Set the all-dirty flag
    method set-all-dirty(Bool:D $dirty) {
        $!dirty-lock.protect: {
            $!all-dirty = $dirty;
        }
    }

    #| Add a dirty rectangle to be considered during compositing
    method add-dirty-rect($x, $y, $w, $h) {
        $!dirty-lock.protect: {
            @!dirty-rects.push(($x, $y, $w, $h)) unless $!all-dirty;
        }
    }

    #| Snapshot current dirty areas, clear internal list, and return snapshot
    method snapshot-dirty-areas() {
        my @dirty;
        $!dirty-lock.protect: {
            @dirty = $!all-dirty ?? ((0, 0, $.w, $.h),) !! @!dirty-rects;
            @!dirty-rects = Empty;

            # Intentionally *NOT* turning off $!all-dirty here; will do that at
            # composite time instead iff the widget understands how to do so
            # XXXX: Flag to change this behavior?
        }
        @dirty
    }
}


#| Extension to Terminal::Print::Widget, Animated and with EventHandling
class Terminal::Widgets::Widget
   is Terminal::Print::Widget
 does Terminal::Print::Animated
 does Terminal::Print::BoxDrawing
 does Terminal::Widgets::Events::EventHandling
 does Terminal::Widgets::DirtyAreas {
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

    #| Determine the terminal connected to the toplevel of this widget
    method terminal() {
        self.toplevel.terminal
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

    #| After moving, call recalc-coord-offsets on self, and set dirty areas if needed
    method move-to($x, $y, $!z = $.z, Bool:D :$dirty = True) {
        my $old-x = $.x;
        my $old-y = $.y;
        callwith($x, $y);

        if $.parent {
            if $dirty && self.parent-dirtyable {
                # Dirty the before and after areas
                $.parent.add-dirty-rect($old-x, $old-y, $.w, $.h);
                $.parent.add-dirty-rect($x,     $y,     $.w, $.h);
            }

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
        my $pos-changed  = $x != $.x || $y != $.y || $z != $.z;
        my $size-changed = $w != $.w || $h != $.h;
        return unless $pos-changed || $size-changed;

        my $add-dirt = self.parent-dirtyable;
        $.parent.add-dirty-rect($.x, $.y, $.w, $.h) if $add-dirt;

        self.move-to($x, $y, $z, :!dirty) if $pos-changed;

        if $size-changed {
            # XXXX: Does not currently save old contents at all
            my $new-grid = $.grid.WHAT.new($w, $h);
            self.replace-grid($new-grid);
        }

        $.parent.add-dirty-rect($x, $y, $w, $h) if $add-dirt;
    }

    #| Clear the frame and set it all-dirty (so it requires composite)
    method clear-frame() {
        $.grid.clear;
        self.set-all-dirty(True);
    }

    #| Composite children with painter's algorithm (in Z order, back to front)
    method draw-frame() {
        # XXXX: Cache the sorted order?
        for @.children.sort({ .?z // 0 }) {
            .composite;

            # Assume children that don't understand the DirtyAreas protocol
            # are always completely dirty (DirtyAreas compositing adds dirty
            # areas as needed, but other children don't know to do so)
            self.add-dirty-rect(.x, .y, .w, .h)
                unless $_ ~~ Terminal::Widgets::DirtyAreas;
        }
    }

    #| Union all dirty areas, update parent's dirty list, and then composite
    method composite(|) {
        my @dirty := self.snapshot-dirty-areas;

        # XXXX: HACK, just assumes entire widget is dirty
        $.parent.add-dirty-rect($.x, $.y, $.w, $.h) if self.parent-dirtyable;

        nextsame;
    }
}
