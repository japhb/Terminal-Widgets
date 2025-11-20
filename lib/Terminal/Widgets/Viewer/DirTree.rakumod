# ABSTRACT: Tree viewer specialized for directory trees

use Color::DirColors;

use Terminal::Widgets::Viewer::Tree;


class Terminal::Widgets::Viewer::DirTree
   is Terminal::Widgets::Viewer::Tree {
    has Color::DirColors:D $.dir-colors .= new-from-env;

    #| Displayed content for a given node itself, not including children
    method node-content($node) {
        # XXXX: TEMP HACK
        my $color = $.dir-colors.sgr-for($node.data.path);
        $color ~ $node.data.short-name ~ "\e[0m"
    }
}
