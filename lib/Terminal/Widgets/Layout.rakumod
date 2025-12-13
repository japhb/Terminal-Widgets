# ABSTRACT: Widget layout using a simplified box model

unit module Terminal::Widgets::Layout;

use Terminal::Widgets::Common;
use Terminal::Widgets::WidgetRegistry;
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
    has UInt:D $.share-w = 1;
    has UInt:D $.share-h = 1;

    # Force clone to call TWEAK, just like bless/new
    method clone {
        my $clone = callsame;
        $clone.Style::TWEAK;
        $clone
    }

    submethod TWEAK() {
        self.Terminal::Widgets::Layout::BoxModel::BoxModel::TWEAK;

        $!min-w //= $!set-w;
        $!max-w //= $!set-w;
        $!min-h //= $!set-h;
        $!max-h //= $!set-h;
        $!set-w //= $!min-w if $!min-w.defined && $!max-w.defined && $!min-w == $!max-w;
        $!set-h //= $!min-h if $!min-h.defined && $!max-h.defined && $!min-h == $!max-h;

        # Prevent non-sensical styles
        fail 'Cannot configure a style width with min (' ~ $!min-w
           ~ ') and max (' ~ $!max-w ~ ') swapped'
            if $!min-w.defined && $!max-w.defined && $!min-w > $!max-w;

        fail 'Cannot configure a style height with min (' ~ $!min-h
           ~ ') and max (' ~ $!max-h ~ ') swapped'
            if $!min-h.defined && $!max-h.defined && $!min-h > $!max-h;

        fail 'Cannot set a style width (' ~ $!set-w
           ~ ') that is not between min (' ~ $!min-w ~ ') and max (' ~ $!max-w ~ ')'
            if $!set-w.defined && $!min-w.defined && $!min-w > $!set-w
            || $!set-w.defined && $!max-w.defined && $!max-w < $!set-w;

        fail 'Cannot set a style height (' ~ $!set-h
           ~ ') that is not between min (' ~ $!min-h ~ ') and max (' ~ $!max-h ~ ')'
            if $!set-h.defined && $!min-h.defined && $!min-h > $!set-h
            || $!set-h.defined && $!max-h.defined && $!max-h < $!set-h;
    }

    multi method gist(Style:D:) {
        my $padding = $.has-padding ?? ($.pt, $.pr, $.pb, $.pl).join(',') !! 0;
        my $border  = $.has-border  ?? ($.bt, $.br, $.bb, $.bl).join(',') !! 0;
        my $margin  = $.has-margin  ?? ($.mt, $.mr, $.mb, $.ml).join(',') !! 0;
        my $wc      = $.width-correction;
        my $hc      = $.height-correction;
        my $lc      = $.left-correction;
        my $rc      = $.right-correction;
        my $tc      = $.top-correction;
        my $bc      = $.bottom-correction;

        'w:(' ~ ($.min-w, $.set-w, $.max-w).map({ $_ // '*'}).join(':')
         ~ (' min' if $.minimize-w) ~ ') ' ~
        'h:(' ~ ($.min-h, $.set-h, $.max-h).map({ $_ // '*'}).join(':')
         ~ (' min' if $.minimize-h) ~ ')'
         ~ (' ' ~ $.sizing-box ~ ' p:' ~ $padding ~ ' b:' ~ $border ~
            ' m:' ~ $margin ~ ' wc:' ~ $wc ~ '=' ~ $lc ~ '+' ~ $rc ~
            ' hc:' ~ $hc ~ '=' ~ $tc ~ '+' ~ $bc
            if $.has-framing)
    }

    multi method gist(Style:U:) {
        'Style:U'
    }
}


#| Role for dynamic layout nodes, tracking both requested and computed styles
role Dynamic
does Terminal::Widgets::Common {
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

                $min-w //= 0 max $pc.min-w - $correction if $pc.min-w.defined;
                $set-w //= 0 max $pc.set-w - $correction if $pc.set-w.defined;
                $max-w //= 0 max $pc-smw   - $correction if $pc-smw.defined;
            }
            else {
                my $correction =    $pc.height-correction(ContentBox)
                               + $style.height-correction(MarginBox);
                my $pc-smh     = $pc.set-h // $pc.max-h;

                $min-h //= 0 max $pc.min-h - $correction if $pc.min-h.defined;
                $set-h //= 0 max $pc.set-h - $correction if $pc.set-h.defined;
                $max-h //= 0 max $pc-smh   - $correction if $pc-smh.defined;
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
    method builder-name() { 'leaf' }

    multi method gist(Leaf:U:) {
        self.gist-name ~ ':U'
    }

    multi method gist(Leaf:D:) {
        self.gist-name ~ '|' ~
        'requested: [' ~ $.requested.gist ~ '] ' ~
        'computed: ['  ~ $.computed.gist  ~ '] ' ~
        'x:' ~ ($.x // '*') ~ ' y:' ~ ($.y // '*') ~
        (' --- [' ~ $.widget.gist ~ ']' if $.widget)
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

    method builder-name() { 'node' }

    multi method gist(Node:U:) {
        self.gist-name ~ ':U'
    }

    multi method gist(Node:D:) {
        my @child-gists = @.children.map: *.gist.indent(4);
        self.gist-name ~ '|' ~
        'requested: [' ~ $.requested.gist ~ '] ' ~
        'computed: ['  ~ $.computed.gist  ~ '] ' ~
        'x:' ~ ($.x // '*') ~ ' y:' ~ ($.y // '*') ~
        (' :vertical' if $.vertical) ~
        (' --- [' ~ $.widget.gist ~ ']' if $.widget) ~
        ($?NL ~ @child-gists.join($?NL) if @.children)
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
            fail 'Width is set to ' ~ $set-w ~ ', outside of min/max ' ~ $min-w
                if $set-w.defined && $set-w != $min-w;
            $set-w = $min-w;
        }
        if $max-h.defined && $min-h == $max-h {
            fail 'Height is set to ' ~ $set-h ~ ', outside of min/max ' ~ $min-h
                if $set-h.defined && $set-h != $min-h;
            $set-h = $min-h;
        }

        # Set values: subtract out and see what's left
        my @child-set-w = @child-style.grep(*.set-w.defined).map:
            { .set-w + .width-correction(MarginBox) };
        my $child-set-w = $.vertical
                          ?? (@child-set-w ?? @child-set-w.max !! 0)
                          !!  @child-set-w.sum;
        my $corrected-child-set-w = $child-set-w - $cwc;

        if @.children == @child-set-w {
            fail 'Set width in parent (' ~ $set-w ~ ') does not match width of children (' ~ $child-set-w ~ ')'
                if $set-w.defined && $set-w != $corrected-child-set-w;
            $set-w = $corrected-child-set-w;
        }
        elsif $set-w.defined {
            my $remain-w = $set-w - $corrected-child-set-w;

            # Need to use @.children instead of @child-style because will need to
            # recompute .computed in the while loop below
            my @unset-w = @.children.grep(!*.computed.set-w.defined)
                                    .sort({-(.computed.min-w +
                                             .computed.width-correction(MarginBox))})
                                    .sort(-?*.computed.minimize-w);
            while @unset-w {
                my $sum    = @unset-w.map(*.computed.share-w).sum;
                my $node   = @unset-w.shift;
                my $before = $node.computed;
                $remain-w -= $before.width-correction(MarginBox);
                fail 'Insufficient remaining width to distribute' if $remain-w < 0;

                my $share  = floor($remain-w * $before.share-w / $sum);
                $share     = 0              if $before.minimize-w;
                $share  max= $before.min-w  if $before.min-w.defined;
                $share  min= $before.max-w  if $before.max-w.defined;
                $remain-w -= $share;

                $node.computed = $before.clone(:set-w($share));
                $node.compute-layout;
            }
        }

        my @child-set-h = @child-style.grep(*.set-h.defined).map:
            { .set-h + .height-correction(MarginBox) };
        my $child-set-h = $.vertical   ?? @child-set-h.sum !!
                          @child-set-h ?? @child-set-h.max !! 0;
        my $corrected-child-set-h = $child-set-h - $chc;

        if @.children == @child-set-h {
            fail 'Set height in parent (' ~ $set-h ~ ') does not match height of children (' ~ $child-set-h ~ ')'
                if $set-h.defined && $set-h != $corrected-child-set-h;
            $set-h = $corrected-child-set-h;
        }
        elsif $set-h.defined {
            my $remain-h = $set-h - $corrected-child-set-h;

            # Need to use @.children instead of @child-style because will need to
            # recompute .computed in the while loop below
            my @unset-h = @.children.grep(!*.computed.set-h.defined)
                                    .sort({-(.computed.min-h +
                                             .computed.height-correction(MarginBox))})
                                    .sort(-?*.computed.minimize-h);
            while @unset-h {
                my $sum    = @unset-h.map(*.computed.share-h).sum;
                my $node   = @unset-h.shift;
                my $before = $node.computed;
                $remain-h -= $before.height-correction(MarginBox);
                fail 'Insufficient remaining height to distribute' if $remain-h < 0;

                my $share  = floor($remain-h * $before.share-h / $sum);
                $share     = 0             if $before.minimize-h;
                $share  max= $before.min-h if $before.min-h.defined;
                $share  min= $before.max-h if $before.max-h.defined;
                $remain-h -= $share;

                $node.computed = $before.clone(:set-h($share));
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

        my $x = $.x + $.computed.left-correction;
        my $y = $.y + $.computed.top-correction;

        if $.vertical {
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $h = .computed.set-h;
                $y += $h + .computed.height-correction(MarginBox);
            }
        }
        else {
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


#| A space consumer around or between layout nodes
class Spacer is Leaf {
    method builder-name() { 'spacer' }
}

#| A visual divider (such as box-drawing lines) between layout nodes
class Divider is Leaf {
    method builder-name() { 'divider' }
}

#| A horizontal scrollbar
class HScrollBar is Leaf {
    method builder-name() { 'hscroll' }

    method default-styles(:$show-end-arrows) {
        %( set-h => 1, min-w => 1 + ?$show-end-arrows )
    }
}

#| A vertical scrollbar
class VScrollBar is Leaf {
    method builder-name() { 'vscroll' }

    method default-styles(:$show-end-arrows) {
        %( set-w => 1, min-h => 1 + ?$show-end-arrows )
    }
}

#| A rich text viewer widget
class RichText is Leaf {
    method builder-name() { 'rich-text' }
}

#| A tree viewer widget
class TreeView is Leaf {
    method builder-name() { 'tree-view' }
}

#| A multi-line auto-scrolling log viewer
class LogViewer is Leaf {
    method builder-name() { 'log-viewer' }
}

#| A navigable tree viewer widget
class TreeViewer is Leaf {
    method builder-name() { 'tree-viewer' }
}

#| A navigable tree viewer widget, specialized for directory trees
class DirTreeViewer is TreeViewer {
    method builder-name() { 'dir-tree-viewer' }
}

#| A simple smoke chart visualization
class SmokeChart is Leaf {
    method builder-name() { 'smoke-chart' }
}

#| A minimal plain text container
class PlainText is Leaf {
    method builder-name() { 'plain-text' }

    method default-styles(:$locale!, :$text = '') {
        my @lines = $locale.plain-text($text).lines;

        %( min-h => @lines.elems,
           min-w => 0 max @lines.map({ $locale.width($_) }).max )
    }
}

#| A multi-line single-select menu
class Menu is Leaf {
    method builder-name() { 'menu' }

    method default-styles(:$locale!, :@items, :%icons) {
        my $max-icon = 0 max %icons.values.map({ $locale.width($_) }).max;
        my $spacing  = 2 + ?$max-icon;

        %( min-h => @items.elems,
           min-w => $spacing + $max-icon +
                    (0 max @items.map({ $locale.width(.<title>) }).max) )
    }
}

#| Single line inputs
class SingleLineInput is Leaf {
    method input-class() { ... }

    method default-styles(|c) {
        my $min-w = self.input-class.min-width(|c);
        %( :$min-w, set-h => 1 )
    }
}

#| A single button
class Button is SingleLineInput {
    method builder-name() { 'button' }
    method input-class()  { ::('Terminal::Widgets::Input::Button') }
}

#| A single checkbox
class Checkbox is SingleLineInput {
    method builder-name() { 'checkbox' }
    method input-class()  { ::('Terminal::Widgets::Input::Checkbox') }
}

#| A single radio button
class RadioButton is SingleLineInput {
    method builder-name() { 'radio-button' }
    method input-class()  { ::('Terminal::Widgets::Input::RadioButton') }
}

#| A single toggle button (looks like a button, acts like a checkbox)
class ToggleButton is SingleLineInput {
    method builder-name() { 'toggle-button' }
    method input-class()  { ::('Terminal::Widgets::Input::ToggleButton') }
}

#| A single-line text input field
class TextInput is SingleLineInput {
    method builder-name() { 'text-input' }
    method input-class()  { ::('Terminal::Widgets::Input::Text') }

    method default-styles() { hash(set-h => 1) }
}


#| A widget node; localizes xy coordinate frame for children
#| (upper left of this widget becomes new 0,0 for children)
class Widget is Node {
    method builder-name() { 'widget' }

    method propagate-xy() {
        my $x = $.computed.left-correction;
        my $y = $.computed.top-correction;

        if $.vertical {
            for @.children {
                .x = $x;
                .y = $y;
                .propagate-xy;
                last without my $h = .computed.set-h;
                $y += $h + .computed.height-correction(MarginBox);
            }
        }
        else {
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


#| A structural node to associate a scrollable child with matched scrollbars
class WithScrollbars is Node {
    method builder-name() { 'with-scrollbars' }
}


# Structural nodes to generate centering node structures

#| A structural node to horizontally center its children
class HCenter is Node {
    method builder-name() { 'hcenter' }
}

#| A structural node to vertically center its children
class VCenter is Node {
    method builder-name() { 'vcenter' }
}

#| A structural node to center its children in both directions
class Center is Node {
    method builder-name() { 'center' }
}


#| Helper class for building style/layout trees
class Builder
 does Terminal::Widgets::WidgetRegistry {
    has $.context is required;

    #| Use Widget registry to automatically find builders
    method FALLBACK(Str:D $name, |c) {
        die "Unable to find a layout class for builder method $name.raku()"
            unless self.builder-exists($name);

        my $layout-class = self.layout-for-builder($name);

        $layout-class ~~ Leaf ?? self.build-leaf($layout-class, |c)
                              !! self.build-node($layout-class, |c)
    }

    #| Helper method for building leaf nodes
    method build-leaf($node-type, :%style, *%extra) {
        my $default = $node-type.default-styles(locale => $.context.locale,
                                                :$.context, :%style, |%extra);
        $node-type.new(:$.context, :%extra,
                       requested => Style.new(|$default, |%style))
    }

    #| Helper method for building nodes with optional children
    method build-node($node-type, *@children, :$vertical, :%style, *%extra) {
        my $default = $node-type.default-styles(locale => $.context.locale,
                                                :$.context, :%style, |%extra);
        $node-type.new(:$.context, :@children, :$vertical, :%extra,
                       requested => Style.new(|$default, |%style))
    }

    #| Helper method for associating a scrollable child with matching scrollbars
    method build-with-scrollbars($scrollable, :%style, *%extra) {
        my $scroll-target = $scrollable.extra<id>
            // die "Must specify a string id for a scrollable to add scrollbars";

        with self {
            .build-node(WithScrollbars, :vertical, :%style,
                        .node(
                            $scrollable,
                            .vscroll(:$scroll-target),
                        ),
                        .node(
                            .hscroll(:$scroll-target),
                            .spacer(style => %(set-w => 1, set-h => 1)),
                        )
                       )
        }
    }

    #| Helper method for building horizontal centering layout
    method build-hcenter(*@children, :%style, *%extra) {
        with self {
            .build-node(HCenter,
                        .node(),
                        .node(|@children, :%style, |%extra),
                        .node(),
                       )
        }
    }

    #| Helper method for building vertical centering layout
    method build-vcenter(*@children, :%style, *%extra) {
        with self {
            .build-node(VCenter, :vertical,
                        .node(),
                        .node(|@children, :%style, |%extra),
                        .node(),
                       )
        }
    }

    #| Helper method for building fully centering layout
    #| (horizontal outer centering, vertical inner centering)
    method build-center(*@children, :%style, *%extra) {
        my %hstyle = %style.clone;
        my %vstyle = %style.clone;
        %hstyle<minimize-h>:delete;
        %vstyle<minimize-w>:delete;

        with self {
            .build-node(Center,
                        .node(),
                        .node(:vertical, style => %hstyle,
                              .node(),
                              .node(|@children, style => %vstyle, |%extra),
                              .node(),
                             ),
                        .node(),
                       )
        }
    }

    # Misc leaf nodes (no children ever)
    method leaf(|c)          { self.build-leaf(Leaf,         |c) }
    method spacer(|c)        { self.build-leaf(Spacer,       |c) }
    method divider(|c)       { self.build-leaf(Divider,      |c) }
    method hscroll(|c)       { self.build-leaf(HScrollBar,   |c) }
    method vscroll(|c)       { self.build-leaf(VScrollBar,   |c) }
    method plain-text(|c)    { self.build-leaf(PlainText,    |c) }
    method smoke-chart(|c)   { self.build-leaf(SmokeChart,   |c) }

    # Viewer leaf nodes (no children ever)
    method rich-text(|c)     { self.build-leaf(RichText,     |c) }
    method tree-view(|c)     { self.build-leaf(TreeView,     |c) }
    method log-viewer(|c)    { self.build-leaf(LogViewer,    |c) }
    method tree-viewer(|c)   { self.build-leaf(TreeViewer,   |c) }
    method dir-tree-viewer(|c) { self.build-leaf(DirTreeViewer, |c) }

    # Input leaf nodes (no children ever)
    method menu(|c)          { self.build-leaf(Menu,         |c) }
    method button(|c)        { self.build-leaf(Button,       |c) }
    method checkbox(|c)      { self.build-leaf(Checkbox,     |c) }
    method text-input(|c)    { self.build-leaf(TextInput,    |c) }
    method radio-button(|c)  { self.build-leaf(RadioButton,  |c) }
    method toggle-button(|c) { self.build-leaf(ToggleButton, |c) }

    # Nodes with optional children
    method node(|c)          { self.build-node(Node,         |c) }
    method widget(|c)        { self.build-node(Widget,       |c) }

    # Nodes with required children
    method with-scrollbars(|c) { self.build-with-scrollbars( |c) }

    # "Gravitational" nodes
    method hcenter(|c)       { self.build-hcenter(           |c) }
    method vcenter(|c)       { self.build-vcenter(           |c) }
    method center(|c)        { self.build-center(            |c) }
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
        die 'This ' ~ self.gist-name ~ ' already contains a widget with id ' ~ $id.raku
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
            my $w = .computed.set-w + .computed.width-correction(MarginBox);
            my $h = .computed.set-h + .computed.height-correction(MarginBox);
            my $geometry = \(:$parent, :layout($_), :x(.x), :y(.y), :$w, :$h);
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
