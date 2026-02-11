# ABSTRACT: Simplified widgets: basic toplevel

use nano;

use Terminal::Widgets::WidgetRegistry;
use Terminal::Widgets::Layout;
use Terminal::Widgets::TopLevel;

constant MarginBox = Terminal::Widgets::Layout::BoxModel::MarginBox;
constant Node      = Terminal::Widgets::Layout::Node;


#| Easy-to-use TopLevel Widget class, with standard build semantics and
#| simplified layout hooks for subclasses
class Terminal::Widgets::Simple::TopLevel
 does Terminal::Widgets::TopLevel
 does Terminal::Widgets::WidgetRegistry {
    has Terminal::Widgets::Layout::Builder:U $.layout-builder-class;

    ### Stubbed hooks for subclass

    method initial-layout($builder, $max-width, $max-height) { Empty }
    method update-layout($layout) { }
    method vertical() { True }


    ### Core implementation

    #| Hand off to subclass to define the initial layout constraints
    method layout-model() {
        with $.layout-builder-class.new(context => $.terminal) {
            .widget(:$.vertical,
                    style => %(max-w => $.w, max-h => $.h),
                    |self.initial-layout($_, $.w, $.h));
        }
    }

    #| Refresh the layout tree based on updated info
    method updated-layout-model() {
        # Top level widget layout is constrained by new terminal size
        $.layout.update-requested(max-w => $.w, max-h => $.h);

        self.update-layout($.layout);

        $.layout
    }

    #| Compute the full UI layout according to its constraints
    method compute-root-layout() {
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

    #| Build widgets from the registered widget library based on dynamic layout
    method build-node($node, $geometry) {
        do given $node.WHAT {
            # XXXX: Temporary workaround while changing content model
            use  Terminal::Widgets::PlainText;
            when Terminal::Widgets::Layout::PlainText {
                my %extra = %($node.extra);
                %extra<c> = %extra<color>:delete if %extra<color>:exists;
                Terminal::Widgets::PlainText.new(|$geometry, |%extra)
            }
            when self.layout-exists($_) {
                self.widget-for-layout($_).new(|$geometry, |$node.extra)
            }
            when Terminal::Widgets::Layout::Divider {
                my $style = $node.extra<line-style> || $geometry<parent>.default-box-style;
                if $node.parent && $node.parent.vertical {
                    my $x1 = $geometry<x>;
                    my $x2 = $x1 + $geometry<w> - 1;
                    my $y  = $geometry<y>;
                    $geometry<parent>.draw-hline($x1, $x2, $y, :$style);
                }
                else {
                    my $x  = $geometry<x>;
                    my $y1 = $geometry<y>;
                    my $y2 = $y1 + $geometry<h> - 1;
                    $geometry<parent>.draw-vline($x, $y1, $y2, :$style);
                }
            }
            default { Nil }
        }
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

    #| Lay out main subwidgets (and dividers/frames, if any)
    method build-layout() {
        note '-> Building TopLevel layout:' if $.debug;

        # Build layout dynamically based on layout constraints from layout-model
        my $t0 = nano;
        my $is-rebuild  = ?$.layout;
        my $layout-root = self.compute-root-layout;
        self.set-layout($layout-root);

        # Actually build widgets and recalculate coordinate offsets recursively
        my $t1 = nano;
        self.build-children($layout-root, self);
        my $t2 = nano;
        self.recalc-coord-offsets($.x, $.y, $.z);
        my $t3 = nano;

        if $.debug {
            self.debug-elapsed($t0, $t1, desc => '1:compute-root-layout');
            self.debug-elapsed($t1, $t2, desc => '2:build-children');
            self.debug-elapsed($t2, $t3, desc => '3:recalc-coord-offsets');
            self.debug-elapsed($t0, $t3);
            note $layout-root.gist.indent(3).subst('   ', '=> ');
        }

        # Return is-rebuild for subclasses
        $is-rebuild
    }
}
