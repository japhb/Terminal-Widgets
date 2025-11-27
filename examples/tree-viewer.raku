# ABSTRACT: Demonstrate the tree viewer widget on a static tree

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::Volatile::Tree;
use Terminal::Widgets::Viewer::Tree;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class TreeViewerDemo is TopLevel {
    has $!root-node = 'Root' => [
                          'One' => [
                              'One One' => [
                                  'One One One',
                                  'One One Two - disestablishmentarianism',
                                  'One One Three',
                                  'One One Four',
                                  'One One Five',
                                  'One One Six',
                              ],
                              'One Two' => [
                                  'One Two One',
                                  'One Two Two',
                                  'One Two Three',
                              ],
                          ],
                          'Two' => [
                              'Two One'
                          ]
                       ];

    method initial-layout($builder, $width, $height) {
        with $builder {
            .button(label => 'Quit',
                    process-input => { $.terminal.quit }),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node(
                .with-scrollbars(style => (:minimize-w),
                    .tree-viewer(id => 'tree', style => %(set-w => 15),
                                 process-click => -> $node {
                                        my $click-log = %.by-id<click-log>;
                                        $click-log.add-entry:
                                            "Click on node $node.data.short-name()\n";
                                        $click-log.refresh-for-scroll;
                                    }),
                ),
                .spacer(),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .with-scrollbars(.log-viewer(id => 'click-log')),
        }
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        %.by-id<tree>.set-root(static-tree($!root-node));
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', TreeViewerDemo, title => 'Tree Viewer Example');
}
