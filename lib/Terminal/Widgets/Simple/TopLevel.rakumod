# ABSTRACT: Simplified widgets: basic toplevel

use Terminal::Widgets::StandardWidgetBuilder;
use Terminal::Widgets::TopLevel;


#| Very basic toplevel widget class, with simplified hooks for subclasses
class Terminal::Widgets::Simple::TopLevel
   is Terminal::Widgets::StandardWidgetBuilder
 does Terminal::Widgets::TopLevel {
    has Terminal::Widgets::Layout::Builder:U $.layout-builder-class;

    ### Stubbed hooks for subclass

    method initial-layout($builder, $max-width, $max-height) { Empty }
    method update-layout($layout) { }
    method vertical() { True }


    ### Core implementation

    #| Hand off to subclass to define the initial layout constraints
    method layout-model() {
        with $.layout-builder-class.new {
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

    #| Lay out main subwidgets (and dividers/frames, if any)
    method build-layout() {
        # Build layout dynamically based on layout constraints from layout-model
        my $is-rebuild  = ?$.layout;
        my $layout-root = self.compute-layout;
        self.set-layout($layout-root);

        # Debug: describe computed layout BEFORE build and coord recalc
        # note $layout-root.gist;

        # Actually build widgets and recalculate coordinate offsets recursively
        self.build-children($layout-root, self);
        self.recalc-coord-offsets($.x, $.y, $.z);

        # Debug: describe computed layout AFTER build and coord recalc
        # note $layout-root.gist;

        # Return is-rebuild for subclasses
        $is-rebuild
    }
}
