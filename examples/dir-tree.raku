# ABSTRACT: Demonstrate the tree view widget for dynamic directory navigation

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::TextContent;
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
                                     sort-by => { -(.path.d), .short-name.fc },
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

        my sub format-line(Str:D $label, Str:D() $value) {
            span-tree(string-span($label, color => 'bold yellow'),
                      pad-span(10 - $label.chars),
                      $value ~ $?NL)
        }

        my $entry = span-tree(
            |($?NL unless $details.empty),
            format-line('Path',     $path),
            |(format-line('Target',   $path.readlink) if $path.l),
            format-line('Mode',     $path.mode),
            format-line('User',     $path.user),
            format-line('Group',    $path.group),
            format-line('Inode',    $path.inode),
            format-line('Size',     $path.s),
            format-line('Created',  $path.created.DateTime),
            format-line('Changed',  $path.changed.DateTime),
            format-line('Modified', $path.modified.DateTime),
            format-line('Accessed', $path.accessed.DateTime),
        );

        $details.add-entry($entry);
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
