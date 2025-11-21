# ABSTRACT: Demonstrate the tree view widget for dynamic directory navigation

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::SpanStyle;
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
                    .dir-tree-viewer(id => 'dir-tree',
                                     process-click => -> $node {
                                         self.show-details($node)
                                     }),
                ),
                .divider(line-style => 'light1', style => %(set-w => 1)),
                .with-scrollbars(style => %( share-w => 2 ),
                    .log-viewer(id => 'details'),
                ),
            ),
        }
    }

    method show-details($node) {
        my $data = $node.data;
        my $path = $data.path;

        my $details = %.by-id<details>;
        $details.add-entry("\n") if $details.log;

        my sub format-line(Str:D $label, Str:D() $value) {
            span-tree('', span('bold yellow', $label),
                          span('', ' ' x 10 - $label.chars),
                          span('', $value))
        }

        $details.add-entry(format-line('Path',     $path));
        $details.add-entry(format-line('Target',   $path.readlink)) if $path.l;
        $details.add-entry(format-line('Mode',     $path.mode));
        $details.add-entry(format-line('User',     $path.user));
        $details.add-entry(format-line('Group',    $path.group));
        $details.add-entry(format-line('Inode',    $path.inode));
        $details.add-entry(format-line('Size',     $path.s));
        $details.add-entry(format-line('Created',  $path.created.DateTime));
        $details.add-entry(format-line('Changed',  $path.changed.DateTime));
        $details.add-entry(format-line('Modified', $path.modified.DateTime));
        $details.add-entry(format-line('Accessed', $path.accessed.DateTime));

        $details.refresh-for-scroll;
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        %.by-id<dir-tree>.set-root(dir-tree-node($*HOME || '/'));
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the demo screen
    App.new.boot-to-screen('demo', DirTreeDemo, title => 'Directory Tree Demo');
}
