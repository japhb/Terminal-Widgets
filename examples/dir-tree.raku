# ABSTRACT: Demonstrate the tree view widget for dynamic directory navigation

use Terminal::Capabilities;

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::TextContent;
use Terminal::Widgets::WrappableBuffer;
use Terminal::Widgets::Volatile::DirTree;

constant Uni1 = Terminal::Capabilities::SymbolSet::Uni1;
constant Dir  = Terminal::Widgets::Volatile::DirTree::Dir;


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
                                     sort-by => { (1 - ($_ ~~ Dir)) ~ .short-name.fc },
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
        # Set root node of tree viewer
        %.by-id<dir-tree>.set-root(dir-tree-node($*HOME || '/'));

        # Set line wrapping style for log: Grapheme wrapping with wrap markers
        my $log        = %.by-id<details>;
        my $marker     = $.terminal.caps.symbol-set >= Uni1 ?? '↳ ' !! '> ';
        my $wrap-style = $log.wrap-style.new:
                         :$.terminal,
                         wrap-mode => GraphemeWrap,
                         wrapped-line-prefix => ' ' x 8 ~ $marker;
        $log.set-wrap-style($wrap-style);
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the demo screen
    App.new.boot-to-screen('demo', DirTreeDemo, title => 'Directory Tree Demo');
}
