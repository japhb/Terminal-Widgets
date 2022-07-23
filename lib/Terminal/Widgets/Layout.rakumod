# ABSTRACT: Widget layout using a simplified box model

unit module Terminal::Widgets::Layout;

use Terminal::Widgets::Layout::BoxModel;


#| Style information (either requested or computed) for a layout node/leaf
class Style
 does Terminal::Widgets::Layout::BoxModel::BoxModel {
    # NOTE: Since Style is immutable we can assume that once instantiated, if
    #       set-* is defined, then min-* and max-* must be as well; likewise,
    #       if min-* and max-* are both defined and the same, then set-* is
    #       defined and the same.

    has UInt $.set-w;
    has UInt $.set-h;
    has UInt $.min-w;
    has UInt $.min-h;
    has UInt $.max-w;
    has UInt $.max-h;
    has Bool $.minimize-w;
    has Bool $.minimize-h;

    submethod TWEAK() {
        self.Terminal::Widgets::Layout::BoxModel::BoxModel::TWEAK;

        $!min-w //= $!set-w;
        $!max-w //= $!set-w;
        $!min-h //= $!set-h;
        $!max-h //= $!set-h;
        $!set-w //= $!min-w if $!min-w.defined && $!max-w.defined && $!min-w == $!max-w;
        $!set-h //= $!min-h if $!min-h.defined && $!max-h.defined && $!min-h == $!max-h;

        # Prevent non-sensical styles
        fail "Cannot configure a style width with min ($!min-w) and max ($!max-w) swapped"
            if $!min-w.defined && $!max-w.defined && $!min-w > $!max-w;

        fail "Cannot configure a style height with min ($!min-h) and max ($!max-h) swapped"
            if $!min-h.defined && $!max-h.defined && $!min-h > $!max-h;

        fail "Cannot set a style width ($!set-w) that is not between min ($!min-w) and max ($!max-w)"
            if $!set-w.defined && $!min-w.defined && $!min-w > $!set-w
            || $!set-w.defined && $!max-w.defined && $!max-w < $!set-w;

        fail "Cannot set a style height ($!set-h) that is not between min ($!min-h) and max ($!max-h)"
            if $!set-h.defined && $!min-h.defined && $!min-h > $!set-h
            || $!set-h.defined && $!max-h.defined && $!max-h < $!set-h;
    }

    multi method gist(Style:D:) {
        $.sizing-box ~ ' ' ~
        'w:(' ~ ($.min-w, $.set-w, $.max-w).map({ $_ // '*'}).join(':')
         ~ (' min' if $.minimize-w) ~ ') ' ~
        'h:(' ~ ($.min-h, $.set-h, $.max-h).map({ $_ // '*'}).join(':')
         ~ (' min' if $.minimize-h) ~ ')'
    }

    multi method gist(Style:U:) {
        'Style:U'
    }
}


#| Role for dynamic layout nodes, tracking both requested and computed styles
role Dynamic {
    has         %.extra;
    has Style   $.requested;
    has Style   $.computed is rw;
    has Dynamic $.parent   is rw;
    has         $.widget   is rw;
    has UInt    $.x        is rw;
    has UInt    $.y        is rw;


    method compute-layout() { ... }
    method propagate-xy()   { ... }

    method default-styles() { hash() }

    method update-requested(*%updates) {
        self.uncompute;
        $!requested = $!requested.clone(|%updates);
    }

    method uncompute() {
        $!computed = Nil;
    }

    method is-set() {
        $.computed && $.computed.set-w.defined && $.computed.set-h.defined
        && $.x.defined && $.y.defined
    }

    method initial-compute() {
        # Start with previously computed styles if available, or requested styles if not
        my $style = $.computed // $.requested;
        my $min-w = $style.min-w;
        my $set-w = $style.set-w;
        my $max-w = $style.max-w;
        my $min-h = $style.min-h;
        my $set-h = $style.set-h;
        my $max-h = $style.max-h;

        if $.parent {
            # Try to pull settings from parent, correcting for box layers --
            # this widget's MarginBox needs to fit in the parent's ContentBox
            my $pc = $.parent.computed;
            if $.parent.vertical {
                my $correction =    $pc.width-correction(ContentBox)
                               + $style.width-correction(MarginBox);
                my $pc-smw     = $pc.set-w // $pc.max-w;

                $min-w //= max 0, $pc.min-w - $correction if $pc.min-w.defined;
                $set-w //= max 0, $pc.set-w - $correction if $pc.set-w.defined;
                $max-w //= max 0, $pc-smw   - $correction if $pc-smw.defined;
            }
            else {
                my $correction =    $pc.height-correction(ContentBox)
                               + $style.height-correction(MarginBox);
                my $pc-smh     = $pc.set-h // $pc.max-h;

                $min-h //= max 0, $pc.min-h - $correction if $pc.min-h.defined;
                $set-h //= max 0, $pc.set-h - $correction if $pc.set-h.defined;
                $max-h //= max 0, $pc-smh   - $correction if $pc-smh.defined;
            }
        }
        else {
            # Try to set values directly
            $set-w //= $max-w // $min-w;
            $set-h //= $max-h // $min-h;
        }

        # Default minimums to 0
        $min-w //= 0;
        $min-h //= 0;

        ($style.clone(:$min-w, :$set-w, :$max-w, :$min-h, :$set-h, :$max-h),
         $min-w, $set-w, $max-w,
         $min-h, $set-h, $max-h)
    }
}


#| A leaf node in the layout tree (no possible children)
class Leaf does Dynamic {
    multi method gist(Leaf:U:) {
        self.^name ~ ':U'
    }

    multi method gist(Leaf:D:) {
        self.^name ~ '|' ~
        "requested: [$.requested.gist()] " ~
        "computed: [$.computed.gist()] " ~
        "x:{$.x // '*'} y:{$.y // '*' }"
    }

    method all-set(Leaf:D:) { self.is-set }

    multi method compute-layout(Leaf:D:) {
        # Use initial DWIM computations for final computed style
        $!computed = self.initial-compute[0];

        self
    }

    method propagate-xy() { }
}


#| A general node in the layout tree (optional children, with tracking of
#| whether children are slotted vertically or horizontally)
class Node does Dynamic {
    has $.vertical;
    has @.children;

    submethod TWEAK() {
        .parent = self for @!children;
    }

    multi method gist(Node:U:) {
        self.^name ~ ':U'
    }

    multi method gist(Node:D:) {
        my @child-gists = @.children.map: *.gist.indent(4);
        self.^name ~ '|' ~
        "requested: [$.requested.gist()] " ~
        "computed: [$.computed.gist()] " ~
        "x:{$.x // '*'} y:{$.y // '*' }" ~
        (" :vertical" if $.vertical) ~
        ("\n" ~ @child-gists.join("\n") if @.children)
    }

    method uncompute() {
        self.Dynamic::uncompute;
        .uncompute for @.children;
    }

    method all-set(Node:D:) {
        self.is-set && all(@.children.map(*.all-set))
    }

    multi method compute-layout(Node:D:) {
        # Do initial DWIM computations
        my ($style,
            $min-w, $set-w, $max-w,
            $min-h, $set-h, $max-h) = self.initial-compute;

        # Assign *partially* computed style to allow children to introspect this node
        $!computed = $style;
        return unless @.children;

        # Compute all children based on partial info so far
        .compute-layout for @.children;

        # Cache box model corrections for our ContentBox
        my $cwc = $!computed.width-correction( ContentBox);
        my $chc = $!computed.height-correction(ContentBox);

        # Incorporate already-known children's settings into current where possible
        my @child-style = @.children.map(*.computed);

        # Minimums: always useful, though calculation varies by orientation
        my @child-min-w = @child-style.map:
                          { (.min-w // 0) + .width-correction( MarginBox) };
        my @child-min-h = @child-style.map:
                          { (.min-h // 0) + .height-correction(MarginBox) };
        my $child-min-w = $.vertical ?? @child-min-w.max !! @child-min-w.sum;
        my $child-min-h = $.vertical ?? @child-min-h.sum !! @child-min-h.max;
        $min-w max= $child-min-w - $cwc;
        $min-h max= $child-min-h - $chc;

        # Maximums: only useful if all non-minimized children have the value defined
        #           for a particular measure *and* that result is >= than the min
        my &child-max-w = $.vertical ?? {.max-w.defined || !.minimize-w} !! { True };
        my @child-max-w = @child-style.grep(&child-max-w).map:
            { .max-w.defined ?? .max-w + .width-correction(MarginBox) !! .max-w };
        unless @child-max-w.grep(!*.defined) {
            my $child-max-w = $.vertical ?? @child-max-w.min !! @child-max-w.sum;
            $max-w min= $child-max-w - $cwc if $child-max-w >= $child-min-w;
        }
        my &child-max-h = $.vertical ?? { True } !! {.max-h.defined || !.minimize-h};
        my @child-max-h = @child-style.grep(&child-max-h).map:
            { .max-h.defined ?? .max-h + .height-correction(MarginBox) !! .max-h };
        unless @child-max-h.grep(!*.defined) {
            my $child-max-h = $.vertical ?? @child-max-h.sum !! @child-max-h.min;
            $max-h min= $child-max-h - $cwc if $child-max-h >= $child-min-h;
        }

        # Check whether min/max are equal (and thus force set to be the same)
        # Note that minimums are always defined by this point (though may be 0)
        if $max-w.defined && $min-w == $max-w {
            fail "Width is set to $set-w, outside of min/max $min-w"
                if $set-w.defined && $set-w != $min-w;
            $set-w = $min-w;
        }
        if $max-h.defined && $min-h == $max-h {
            fail "Height is set to $set-h, outside of min/max $min-h"
                if $set-h.defined && $set-h != $min-h;
            $set-h = $min-h;
        }

        # Set values: subtract out and see what's left
        my @child-set-w = @child-style.grep(*.set-w.defined).map:
            { .set-w + .width-correction(MarginBox) };
        my $child-set-w = $.vertical
                          ?? (@child-set-w ?? @child-set-w.max !! 0)
                          !!  @child-set-w.sum;

        if @.children == @child-set-w {
            fail "Set width in parent ($set-w) does not match width of children ($child-set-w)"
                if $set-w.defined && $set-w != $child-set-w - $cwc;
            $set-w = $child-set-w - $cwc;
        }
        elsif $set-w.defined {
            my $remain-w = $set-w + $cwc - $child-set-w;

            # Need to use @.children instead of @.child-style because will need to
            # recompute .computed in the while loop below
            my @unset-w = @.children.grep(!*.computed.set-w.defined).sort(-?*.computed.minimize-w);
            while @unset-w {
                fail "Negative remaining width to distribute" if $remain-w < 0;
                my $share  = floor $remain-w / @unset-w;
                my $node   = @unset-w.shift;
                my $correction = $node.computed.width-correction(MarginBox);
                $share     = 0                    if $node.computed.minimize-w;
                $share  max= $node.computed.min-w if $node.computed.min-w.defined;
                $share    += $correction;
                $remain-w -= $share;

                $node.computed = $node.computed.clone(:set-w($share - $correction));
                $node.compute-layout;
            }
        }

        my @child-set-h = @child-style.grep(*.set-h.defined).map:
            { .set-h + .height-correction(MarginBox) };
        my $child-set-h = $.vertical   ?? @child-set-h.sum !!
                          @child-set-h ?? @child-set-h.max !! 0;

        if @.children == @child-set-h {
            fail "Set height in parent ($set-h) does not match height of children ($child-set-h)"
                if $set-h.defined && $set-h != $child-set-h - $chc;
            $set-h = $child-set-h - $chc;
        }
        elsif $set-h.defined {
            my $remain-h = $set-h + $chc - $child-set-h;

            # Need to use @.children instead of @.child-style because will need to
            # recompute .computed in the while loop below
            my @unset-h = @.children.grep(!*.computed.set-h.defined).sort(-?*.computed.minimize-h);
            while @unset-h {
                fail "Negative remaining height to distribute" if $remain-h < 0;
                my $share  = floor $remain-h / @unset-h;
                my $node   = @unset-h.shift;
                my $correction = $node.computed.height-correction(MarginBox);
                $share     = 0                    if $node.computed.minimize-h;
                $share  max= $node.computed.min-h if $node.computed.min-h.defined;
                $share    += $correction;
                $remain-h -= $share;

                $node.computed = $node.computed.clone(:set-h($share - $correction));
                $node.compute-layout;
            }
        }

        # Assign final computed style
        $!computed .= clone(:$min-w, :$set-w, :$max-w,
                            :$min-h, :$set-h, :$max-h);

        self
    }

    method propagate-xy() {
        # Stop propagating silently if current node has not been placed properly
        return unless $.x.defined && $.y.defined;

        if $.vertical {
            my $x = $.x + $.computed.left-correction(ContentBox);
            my $y = $.y + $.computed.top-correction( ContentBox);
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $h = .computed.set-h;
                $y += $h + .computed.height-correction(MarginBox);
            }
        }
        else {
            my $x = $.x + $.computed.left-correction(ContentBox);
            my $y = $.y + $.computed.top-correction( ContentBox);
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $w = .computed.set-w;
                $x += $w + .computed.width-correction(MarginBox);
            }
        }
    }
}


#| A visual divider (such as box-drawing lines) between layout nodes
class Divider is Leaf { }

#| A multi-line auto-scrolling log viewer
class LogViewer is Leaf { }

#| Single line inputs
class SingleLineInput is Leaf {
    method default-styles() { hash(set-h => 1) }
}

#| A single button
class Button is SingleLineInput { }

#| A single checkbox
class Checkbox is SingleLineInput { }

#| A single radio button
class RadioButton is SingleLineInput { }

#| A single-line text input field
class TextInput is SingleLineInput { }


#| A framing node
# class Frame   is Node { }

#| A widget node; localizes xy coordinate frame for children
#| (upper left of this widget becomes new 0,0 for children)
class Widget  is Node {
    method propagate-xy() {
        if $.vertical {
            my $x = $.computed.left-correction(ContentBox);
            my $y = $.computed.top-correction( ContentBox);
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $h = .computed.set-h;
                $y += $h + .computed.height-correction(MarginBox);
            }
        }
        else {
            my $x = $.computed.left-correction(ContentBox);
            my $y = $.computed.top-correction( ContentBox);
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $w = .computed.set-w;
                $x += $w + .computed.width-correction(MarginBox);
            }
        }
    }
}


#| Helper class for building style/layout trees
class Builder {
    # Misc leaf nodes (no children ever)
    method leaf(         :%style, *%extra) {
        my $default      = Leaf.default-styles;
        Leaf.new:        :%extra, requested => Style.new(|$default, |%style) }
    method divider(      :%style, *%extra) {
        my $default      = Divider.default-styles;
        Divider.new:     :%extra, requested => Style.new(|$default, |%style) }
    method log-viewer(   :%style, *%extra) {
        my $default      = LogViewer.default-styles;
        LogViewer.new:   :%extra, requested => Style.new(|$default, |%style) }

    # Input leaf nodes (no children ever)
    method button(       :%style, *%extra) {
        my $default      = Button.default-styles;
        Button.new:      :%extra, requested => Style.new(|$default, |%style) }
    method checkbox(     :%style, *%extra) {
        my $default      = Checkbox.default-styles;
        Checkbox.new:    :%extra, requested => Style.new(|$default, |%style) }
    method radio-button( :%style, *%extra) {
        my $default      = RadioButton.default-styles;
        RadioButton.new: :%extra, requested => Style.new(|$default, |%style) }
    method text-input(   :%style, *%extra) {
        my $default      = TextInput.default-styles;
        TextInput.new:   :%extra, requested => Style.new(|$default, |%style) }

    # Nodes with optional children
    method node(    *@children, :$vertical, :%style, *%extra) {
        my $default = Node.default-styles;
        Node.new:   :@children, :$vertical, :%extra,
                    requested => Style.new(|$default, |%style) }
    # method frame(   *@children, :$vertical, :%style, *%extra) {
    #     my $default = Frame.default-styles;
    #     Frame.new:  :@children, :$vertical, :%extra,
    #                 requested => Style.new(|$default, |%style) }
    method widget(  *@children, :$vertical, :%style, *%extra) {
        my $default = Widget.default-styles;
        Widget.new: :@children, :$vertical, :%extra,
                    requested => Style.new(|$default, |%style) }
}


#| Role for UI Widgets that are dynamically built using the above system
role WidgetBuilding {
    has %.by-id;

    # Required methods
    method layout-model()               { ... }
    method updated-layout-model()       { ... }
    method build-node($node, $geometry) { ... }

    #| Throw an exception if a widget with a given id is already known
    method !ensure-new-id($id) {
        die "This {self.^name} already contains a widget with id '$id'"
            if %.by-id{$id}:exists;
    }

    #| Cache the id for a particular widget, erroring if duplicated
    method cache-widget-id($widget) {
        if $widget.id -> $id {
            self!ensure-new-id($id);
            %!by-id{$id} = $widget;
        }
    }

    #| Compute the UI layout according to its constraints
    method compute-layout() {
        # Build a layout model (or reuse an existing one) for this Widget
        my $layout-root = $.layout ?? self.updated-layout-model
                                   !! self.layout-model;

        # Ask the layout model to compute its own layout details and
        # propagate positioning to children
        $layout-root.compute-layout;
        $layout-root.x  = $.x;
        $layout-root.y  = $.y;
        $layout-root.propagate-xy;

        $layout-root
    }

    #| Build actual Widgets for the children of a given layout-node
    method build-children($layout-node, $parent) {
        # Only Layout::Node subclasses have children; a Layout::Leaf does not
        return unless $layout-node ~~ Node;

        for $layout-node.children {
            # Along with computed XYWH, also include child's parent Widget and
            # child's associated Layout::Dynamic object in the geometry info
            my $geometry = \(:$parent, :layout($_),
                             :x(.x), :y(.y),
                             :w(.computed.set-w),
                             :h(.computed.set-h));
            if .widget && .widget.parent === $parent && .widget.layout === $_ {
                .widget.update-geometry(|$geometry);
            }
            else {
                .widget = self.build-node($_, $geometry);
                self.cache-widget-id(.widget) if .widget;
            }

            # If build-node returned a defined widget, it's the new parent for
            # recursion; otherwise it's just an internal node or a non-Widget
            # and the current parent widget should still be used
            self.build-children($_, .widget // $parent);
        }
    }
}


# XXXX: Ideas for allowing resize/reorder/etc.
#
# * Each widget keeps a reference to its layout object, and vice versa
# * When triggering relayout, check top level; if :U, layout from scratch, otherwise update
# * When rebuilding, check widget ref; if :U, build it, otherwise update
# * When adding or removing layout node or widget, do the same to its dual
# * Encode layout constraints as closures that can be rerun for relayout
