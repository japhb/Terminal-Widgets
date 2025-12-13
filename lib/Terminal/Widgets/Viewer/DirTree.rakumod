# ABSTRACT: Tree viewer specialized for directory trees

use Color::DirColors;

use Terminal::Widgets::TextContent;
use Terminal::Widgets::Layout;
use Terminal::Widgets::Viewer::Tree;


#| Tree viewer class specialized for directory trees, with dircolors awareness
class Terminal::Widgets::Viewer::DirTree
   is Terminal::Widgets::Viewer::Tree {
    has Color::DirColors:D $.dir-colors .= new-from-env;

    method layout-class() { Terminal::Widgets::Layout::DirTreeViewer }

    submethod TWEAK() {
        self.set-sort-by(*.short-name) unless self.sort-by;
    }

    #| Displayed content for a given node itself, not including children
    method node-content($node) {
        my $color = $.dir-colors.color-for($node.data.path);
        $color = 'inverse ' ~ $color if $node === $.current-node;
        render-span($node.data.short-name, $color)
    }
}


# Register Viewer::DirTree as a buildable widget type
Terminal::Widgets::Viewer::DirTree.register;
