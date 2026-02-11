# ABSTRACT: Simplified widgets: basic toplevel

use nano;

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

    #| Lay out main subwidgets (and dividers/frames, if any)
    method build-layout() {
        note '-> Building TopLevel layout:' if $.debug;

        # Build layout dynamically based on layout constraints from layout-model
        my $t0 = nano;
        my $is-rebuild  = ?$.layout;
        my $layout-root = self.compute-layout;
        self.set-layout($layout-root);

        # Actually build widgets and recalculate coordinate offsets recursively
        my $t1 = nano;
        self.build-children($layout-root, self);
        my $t2 = nano;
        self.recalc-coord-offsets($.x, $.y, $.z);
        my $t3 = nano;

        if $.debug {
            self.debug-elapsed($t0, $t1, desc => '1:compute-layout');
            self.debug-elapsed($t1, $t2, desc => '2:build-children');
            self.debug-elapsed($t2, $t3, desc => '3:recalc-coord-offsets');
            self.debug-elapsed($t0, $t3);
            note $layout-root.gist.indent(3).subst('   ', '=> ');
        }

        # Return is-rebuild for subclasses
        $is-rebuild
    }
}
