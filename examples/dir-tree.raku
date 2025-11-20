# ABSTRACT: Demonstrate the tree view widget for dynamic directory navigation

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::Volatile::DirTree;

#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class DirTreeDemo is TopLevel {
    method initial-layout($builder, $width, $height) {
        my %style;

        with $builder {
            .button(label => 'Quit', process-input => { $.terminal.quit }),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node(
                .with-scrollbars(
                    .dir-tree-viewer(id => 'dir-tree', style => %(set-w => 15)),
                ),
                .spacer(),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .with-scrollbars(.log-viewer(id => 'click-log')),
        }
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        %.by-id<dir-tree>.set-root(dir-tree-node('/'));
        %.by-id<dir-tree>.display-root.set-expanded(True);
        %.by-id<dir-tree>.display-root.children.first(*.data.short-name eq 'boot').set-expanded(True);
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the demo screen
    App.new.boot-to-screen('demo', DirTreeDemo, title => 'Directory Tree Demo');
}
