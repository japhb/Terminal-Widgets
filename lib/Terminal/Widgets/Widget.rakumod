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
            my $focusable =  @.children.first(*.^can('process-input'))
                          || @.children.first(Terminal::Widgets::Events::EventHandling);
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

    #| Draw framing (padding, border, margin) for current widget
    method draw-framing() {
        # XXXX: Detect unchanged style and avoid extra work?
        # XXXX: What about dirty areas?
        my $style = self.layout.computed;
        if $style && $style.has-framing {
            # XXXX: Avoid explicitly drawing padding and/or margin if they
            #       have no color and have not been dirtied?
            # XXXX: Does not clear old framing elements
            self.draw-margin  if $style.has-margin;
            self.draw-border  if $style.has-border;
            self.draw-padding if $style.has-padding;
        }
    }

    #| Draw margin
    method draw-margin() {
    }

    #| Draw border
    method draw-border() {
        my $style = self.layout.computed;
        my $x1    = $style.ml;
        my $y1    = $style.mt;
        my $x2    = $.w - $style.mr - 1;
        my $y2    = $.h - $style.mb - 1;

        # Draw equal-width portion of border as efficiently as possible
        my $min = min $style.bt, $style.br, $style.bb, $style.bl;
        for ^$min {
            self.draw-box($x1, $y1, $x2, $y2, color => 'white');
            # XXXX: Support visually equal spacing: $x1 += 2; $x2 -= 2;
            # XXXX: Would need sizing support in BoxModel also ...
            ++$x1; --$x2;
            ++$y1; --$y2;
        }

        # XXXX: Draw remaining partial borders
        my $bt = $style.bt - $min;
        my $br = $style.br - $min;
        my $bb = $style.bb - $min;
        my $bl = $style.bl - $min;
    }

    #| Draw padding
    method draw-padding() {
    }

    #| Clip a rectangle to the content area of this widget
    method clip-to-content-area($dx is copy, $dy is copy, $w is copy, $h is copy,
                                $sx is copy = 0, $sy is copy = 0) {
        my $style = self.layout.computed;
        my $ct    = $style.top-correction;
        my $cl    = $style.left-correction;
        my $cr    = $.w - $style.right-correction;
        my $cb    = $.h - $style.bottom-correction;

        # Adjust for upper-left corner outside of content area:
        # * Move   DX,DY (dest-X,dest-Y) back into content area
        # * Adjust SX,SY (source-X,source-Y) to compensate
        # * Shrink W,H   (Width,Height) to compensate
        if $dx < $cl {
            my $xd = $cl - $dx;
            $w    -= $xd;
            $sx   += $xd;
            $dx    = $cl;
        }
        if $dy < $ct {
            my $yd = $ct - $dy;
            $h    -= $yd;
            $sy   += $yd;
            $dy    = $ct;
        }

        # If it's entirely outside the content area or the rectangle doesn't
        # have positive extent in both dimensions, clip to zero size
        if $dx >= $cr || $dy >= $cb || $w <= 0 || $h <= 0 {
            # Empty rect at (possibly adjusted) X,Y
            ($dx, $dy, 0, 0, $sx, $sy)
        }
        else {
            # Shrink the rectangle if it extends past the right or bottom edge
            # of the content area; return clipped but non-empty rect with
            # updated source location
            ($dx, $dy, ($w min $cr - $dx), ($h min $cb - $dy), $sx, $sy)
        }
    }

    #| Copy from a source grid to the content area of this widget, protected by
    #| this widget's grid lock (as per Terminal::Print::Grid rules).
    method copy-to-content-area($source) {
        # NOTE: Micro-optimized a bit because it's on a very hot path

        # Clip to our content area and check that the result is non-empty
        my $clipped = self.clip-to-content-area($source.x, $source.y,
                                                $source.w, $source.h);
        my ($dx, $dy, $w, $h, $sx, $sy) = @$clipped;
        return $clipped unless $w && $h;

        # Look through abstractions to true underlying grid arrays
        my $dg  = $.grid.grid;
        my $sg  = $source.grid;
           $sg .= grid if $sg ~~ Terminal::Print::Grid;

        # Actually do the copy, optimizing for full-source-width copies if possible
        if !$sx && $w == $source.w {
            # Fast path; whole source rows can be copied
            $.grid.with-grid-lock: {
                $dg.AT-POS($dy + $_).splice($dx, $w, $sg.AT-POS($sy + $_)) for ^$h;
            }
        }
        else {
            # General path
            my $sx2 = $sx + $w - 1;
            $.grid.with-grid-lock: {
                $dg.AT-POS($dy + $_).splice($dx, $w, $sg.AT-POS($sy + $_)[$sx..$sx2]) for ^$h;
            }
        }

        # Pass clipped coordinates back to callers to avoid recalculation
        $clipped
    }

    #| Copy from a source grid to the content area of this widget as with
    #| .copy-to-content-area, and then print the modified area, all while
    #| holding this widget's grid lock (as per Terminal::Print::Grid rules).
    method print-to-content-area($source) {
        # NOTE: Micro-optimized a bit because it's on a very hot path
        $.grid.with-grid-lock: {
            my ($x1, $y1, $w, $h) = self.copy-to-content-area($source);
            my $x2 = $x1 + $w - 1;
            my $g  = $.grid;

            ($y1 .. ($y1 + $h - 1))
                .map({ $g.span-string($x1, $x2, $_) }).join.print
                if $w && $h;
        }
    }

    #| Union all dirty areas, update parent's dirty list if needed, and composite
    method composite(|) {
        my @dirty := self.snapshot-dirty-areas;

        # XXXX: HACK, just assumes entire composed area is dirty on both paths
        if $.parent ~~ Terminal::Widgets::Widget:D {
            if $.parent.is-current-toplevel && $.parent.grid === $*TERMINAL.current-grid {
                $.parent.print-to-content-area(self);
            }
            else {
                my ($x, $y, $w, $h) = $.parent.copy-to-content-area(self);
                $.parent.add-dirty-rect($x, $y, $w, $h);
            }
        }
        else {
            $.parent.add-dirty-rect($.x, $.y, $.w, $.h) if self.parent-dirtyable;
            nextsame;
        }
    }
}
