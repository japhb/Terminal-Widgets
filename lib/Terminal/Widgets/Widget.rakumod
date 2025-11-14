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
    method set-all-dirty(Bool:D $dirty = True) {
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
            $!all-dirty   = False;
        }
        @dirty
    }

    #| Merge and simplify dirty area list, returning a hopefully shorter list
    method merge-dirty-areas(@dirty) {
        #  Note: There is a lot of room for optimization tradeoffs here.
        #  The initial algorithm is very simple (simply bounding the AABBs),
        #  but a more advanced algorithm might for instance try to isolate
        #  disjoint areas to reduce unneeded 'clean area' copying.

        # If there's nothing to merge, just pass through
        return @dirty if @dirty <= 1;

        # Otherwise, start merging axis-aligned bounding boxes, converting
        # as needed between rect (x, y, w, h) and AABB (x1, y1, x2, y2) forms.
        my $first = @dirty[0];
        my $x1    = $first[0];
        my $y1    = $first[1];
        my $x2    = $first[0] + $first[2] - 1;
        my $y2    = $first[1] + $first[3] - 1;

        for 1 ..^ @dirty {
            my $dirty = @dirty[$_];
            $x1 min= $dirty[0];
            $y1 min= $dirty[1];
            $x2 max= $dirty[0] + $dirty[2] - 1;
            $y2 max= $dirty[1] + $dirty[3] - 1;
        }

        # Final conversion back to (x, y, w, h) form as only merged rect
        my $rect   = ($x1, $y1, $x2 - $x1 + 1, $y2 - $y1 + 1);
        my @merged = $rect,;
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


    # gist that improves readability and doesn't pull in widget backing grid
    method gist() {
        my @flags = self.gist-flags.grep(?*);

        # Determine dirty areas without changing dirty state
        my $dirty;
        $!dirty-lock.protect: {
            # Heuristic for 'a single dirty rect covers the whole widget by
            # itself, even if $!all-dirty is not set'
            my $soft-all = @!dirty-rects.first({ .[0] <= 0
                                              && .[1] <= 0
                                              && .[2] >= $.w - .[0]
                                              && .[3] >= $.h - .[1] });
            $dirty = $!all-dirty   ?? 'ALL' !!
                     $soft-all     ?? 'soft-all' !!
                     @!dirty-rects ?? @!dirty-rects.raku !!
                                      'none';
        }

        # Defang possibly undefined values
        my sub d($v) { $v // '*' }

        self.gist-name ~ '|' ~ @flags.join(',')
        ~ ' w:' ~ d($.w) ~ ',h:' ~ d($.h)
        ~ ' x:' ~ d($.x) ~ ',y:' ~ d($.y) ~ ',z:' ~ d($.z)
        ~ ' xo:' ~ d($.x-offset) ~ ',yo:' ~ d($.y-offset) ~ ',zo:' ~ d($.z-offset)
        ~ ' dirty:' ~ $dirty
    }

    # Shortened name for gists
    method gist-name() {
        self.^name.subst('Terminal::Widgets::', '')
    }

    # General widget gist flags
    method gist-flags() {
        my $is-toplevel = self.toplevel === self;

        ('id:' ~ $.id.raku if $.id),
        ((self.is-current-toplevel ?? 'CURRENT-TOPLEVEL' !! 'is-toplevel') if $is-toplevel)
    }

    #| Wrap an existing T::P::Grid into a T::W::Widget with proper layout
    #| styling information and proper linkups to widget and layout trees
    method new-from-grid($grid, |c) {
        callsame.fix-layout
    }

    #| Fix the current layout of the widget by computing a fixed Layout from
    #| the widget's current attributes, and then setting the widget's current
    #| layout to that newly computed fixed Layout object
    method fix-layout() {
        self.set-layout(self.as-fixed-layout)
    }

    #| Create a fixed Layout object based on current Widget details, which may
    #| have been computed dynamically or specified manually
    method as-fixed-layout() {
        my $parent    = $.parent.?layout;
        my $requested = Terminal::Widgets::Layout::Style.new(set-w => $.w,
                                                             set-h => $.h);
        # XXXX: What about widgets with children?  Decide dynamically or always
        #       go with Leaf or Widget respectively?
        my $layout    = Terminal::Widgets::Layout::Leaf.new(:$requested, :$parent,
                                                            :$.x, :$.y);
        $layout.compute-layout
    }

    #| Set this widget's layout attribute, and set that layout's widget
    #| attribute to this widget.  Used for bootstrapping, such as setting
    #| TopLevel's layout or building the layout for a widget created from
    #| an existing grid.
    method set-layout($!layout) { $!layout.widget = self }

    #| Non-TopLevel Widgets cannot be the terminal's current-toplevel
    method is-current-toplevel(--> False) { }

    #| Find the nearest ancestor (or self) that doesn't have a Widget parent,
    #| and thus should be the nearest 'toplevel' (without use'ing TopLevel)
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
        # note 'default-focus is ' ~ self.default-focus.gist-name;
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

    #| Compute the width of the content area (widget minus framing), min 0
    method content-width(--> UInt:D) {
        0 max $.w - $.layout.computed.width-correction
    }

    #| Compute the height of the content area (widget minus framing), min 0
    method content-height(--> UInt:D) {
        0 max $.h - $.layout.computed.height-correction
    }

    #| Compute the X, Y, W, H rect of the content area (widget minus framing);
    #| all values are returned as UInt:D (>= 0)
    method content-rect(Terminal::Widgets::Layout::Style:D $layout
                        = self.layout.computed) {
        (0 max $layout.left-correction,
         0 max $layout.top-correction,
         0 max $.w - $layout.width-correction,
         0 max $.h - $layout.height-correction)
    }

    #| Clear the frame and set it all-dirty (so it requires composite)
    method clear-frame() {
        $.grid.clear;
        self.set-all-dirty;
    }

    #| Composite children with painter's algorithm (in Z order, back to front)
    #| with framing (padding, border, margin) and then content drawn at Z = 0
    method draw-frame() {
        # If children exist, do full painter's algorithm
        if @.children {
            # XXXX: Clip children to content area?

            # XXXX: Cache the sorted order?  Needs careful invalidation handling.
            my %grouped = @.children.sort({ .?z // 0 }).classify({ (.?z // 0) > 0 });

            # Draw children behind framing/content
            for @(%grouped{False} // Empty) {
                .composite;

                # Assume children that don't understand the DirtyAreas protocol
                # are always completely dirty (DirtyAreas compositing adds dirty
                # areas as needed, but other children don't know to do so)
                self.add-dirty-rect(.x, .y, .w, .h)
                    unless $_ ~~ Terminal::Widgets::DirtyAreas;
            }

            # Draw framing, then content
            self.draw-framing;
            self.draw-content;

            # Draw children in front of framing/content
            for @(%grouped{True} // Empty) {
                .composite;

                # Assume children that don't understand the DirtyAreas protocol
                # are always completely dirty (DirtyAreas compositing adds dirty
                # areas as needed, but other children don't know to do so)
                self.add-dirty-rect(.x, .y, .w, .h)
                    unless $_ ~~ Terminal::Widgets::DirtyAreas;
            }
        }
        # If no children, just draw framing then content
        else {
            self.draw-framing;
            self.draw-content;
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

    #| Draw content in content area
    method draw-content() {
        # XXXX: Just a stub for now
    }

    #| Render spans on a single line, optimizing for monospace spans
    #
    #  NOTE: This is a core rendering routine in the span-centric drawing
    #        model and must optimize for performance.  Thus draw-line-spans
    #        assumes that the surrounding drawing code has validated its
    #        arguments BEFORE passing them in, rather than validating them
    #        anew on every single call.
    #
    #        It also optimizes drawing under the assumption that no characters
    #        to be drawn are 0-width. While 0-width is common for *codepoints*,
    #        it should not be true of *graphemes* that you intend to display.
    #        In particular, it will probably do the wrong thing with 0-width
    #        control characters embedded in the string, such as BiDi overrides.
    #
    method draw-line-spans(UInt:D $line-x is copy, UInt:D $line-y,
                           UInt:D $w, @line, UInt:D :$x-scroll = 0,
                           :$locale = self.terminal.locale) {

        # This algorithm uses a lot of parameters and working variables;
        # here's a quick reference:
        #
        # @line             Array of Spans to be drawn on this line
        # $_ (topic)        Current Span object within the @line array
        #
        # $line-x,$line-y   Current drawing coordinates on the backing grid
        # $w                Width in cells of visible drawable area
        # $x-scroll         Count of cells the drawing area is scrolled horizontally
        # $span-x           Count of Span cells processed *so far* during this call
        # $next             Cells expected processed *after* current Span is complete
        #
        # $char             Current character within current Span's text
        # $locale           Locale in which to calculate character widths
        # $width            Width of current character
        # $c-next           Next $line-x after drawing the current character
        # $cell             Colored cell to be drawn in grid for current character

        my $span-x = 0;
        for @line {
            my $next = $span-x + .width;
            if .width == .text.chars {
                # Span is monospace (assuming no 0-width characters in .text)

                if $x-scroll <= $span-x && $next <= $x-scroll + $w  {
                    # Span fully visible and monospace; render entire span and
                    # move line-x the full width. This is the FASTEST span path.
                    $.grid.set-span($line-x, $line-y, .text, .color);
                    $line-x += .width;
                }
                elsif $x-scroll < $next {
                    # Span partially visible and monospace; render visible
                    # substring and move line-x accordingly.  This is the
                    # MEDIUM speed path.
                    my $start   = 0 max $x-scroll - $span-x;
                    my $max-len = 0 max $w - (0 max $span-x - $x-scroll);
                    my $text    = substr(.text, $start, $max-len);

                    $.grid.set-span($line-x, $line-y, $text, .color);
                    $line-x += $text.chars;
                }
                # else monospace span is not visible, so don't draw this span
            }
            elsif $x-scroll < $next {
                # Span is duospaced and possibly visible, but may be cut off by
                # x-scroll or width; need to render cell-by-cell.  This is a
                # potentially SLOW path!

                # XXXX: Run this for loop with grid lock held and update
                #       cells manually to avoid repeated call overhead?

                # XXXX: Currently leaves untouched split character cells;
                #       should this overwrite with ' ' instead?

                for .text.comb -> $char {
                    my $width  = $locale.width($char);
                    my $c-next = $line-x + $width;

                    # Wide char cut off (split) by drawing area width, done
                    last if $c-next > $w;

                    if $x-scroll <= $span-x {
                        # Character fully visible; update optionally-colored
                        # first cell, empty second cell if character was wide,
                        # and move line-x forward by full character width.

                        my $cell = .color ?? $.grid.cell($char, .color) !! $char;
                        $.grid.change-cell($line-x,     $line-y, $cell);
                        $.grid.change-cell($line-x + 1, $line-y, '')
                            if $width > 1;
                        $line-x = $c-next;
                    }
                    elsif $x-scroll == $span-x + 1 && $width == 2 {
                        # Wide char split by x-scroll, skip forward 1 cell
                        $line-x++;
                    }

                    $span-x += $width;
                }
            }
            # else span has been scrolled past, so don't draw this span

            # Span complete, update span-x and check if any drawing width left
            last if ($span-x = $next) - $x-scroll >= $w;
        }
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
    method copy-to-content-area($source, $srect = (0, 0, $source.w, $source.h)) {
        # NOTE: Micro-optimized a bit because it's on a very hot path

        # Clip to our content area and check that the result is non-empty
        my $clipped = self.clip-to-content-area($source.x + $srect[0],
                                                $source.y + $srect[1],
                                                $srect[2],  $srect[3],
                                                $srect[0],  $srect[1]);
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
    method print-to-content-area($source, $srect = (0, 0, $source.w, $source.h)) {
        # NOTE: Micro-optimized a bit because it's on a very hot path
        $.grid.with-grid-lock: {
            my ($x1, $y1, $w, $h) = self.copy-to-content-area($source, $srect);
            my $x2 = $x1 + $w - 1;
            my $g  = $.grid;

            ($y1 .. ($y1 + $h - 1))
                .map({ $g.span-string($x1, $x2, $_) }).join.print
                if $w && $h;
        }
    }

    #| Return an optionally framed debug rendering of the current widget grid
    method debug-grid(Bool :$framed = True) {
        my $grid = $.grid.grid;
        my $vert = $framed ?? '│' !! '';

        ('┌' ~ '─' x $.w ~ '┐' ~ $?NL if $framed) ~
        $grid.map({ $vert ~ .join ~ $vert ~ $?NL }).join ~
        ('└' ~ '─' x $.w ~ '┘'        if $framed)
    }

    #| Union all dirty areas, update parent's dirty list if needed, and composite
    method composite(|) {
        my @dirty  := self.snapshot-dirty-areas;
        my @merged := self.merge-dirty-areas(@dirty);
        my $debug   = +($*DEBUG // 0);

        note 'Compositing:' if $debug >= 2;
        note Backtrace.new.Str.subst(/' at ' \S+/, '', :g) if $debug >= 3;

        if $.parent ~~ Terminal::Widgets::Widget:D {
            if $.parent.is-current-toplevel && $.parent.grid === $*TERMINAL.current-grid {
                note '  Printing to content area: ' ~ $.gist if $debug;
                note self.debug-grid if $debug >= 2;

                $.parent.print-to-content-area(self, $_) for @merged;
            }
            else {
                note '  Copying to content area and dirtying parent: ' ~ $.gist if $debug;
                note self.debug-grid if $debug >= 2;

                for @merged {
                    my ($x, $y, $w, $h) = $.parent.copy-to-content-area(self, $_);
                    $.parent.add-dirty-rect($x, $y, $w, $h);
                }
            }
        }
        else {
            note '  FOLLOWING OLD COMPOSITE PATH FOR ' ~ self.^name ~ ' WITH PARENT ' ~ $.parent.^name if $debug;
            note self.debug-grid if $debug >= 2;

            # XXXX: HACK, just assumes entire composed area is dirty
            $.parent.add-dirty-rect($.x, $.y, $.w, $.h) if self.parent-dirtyable;

            # Invalidate T::P::Grid::grid-string cache
            $.grid.change-cell(0, 0, $.grid.grid[0][0]);

            nextsame;
        }
    }
}
