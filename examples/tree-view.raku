# ABSTRACT: Demonstrate the tree view widget

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::TreeView;
use Terminal::Widgets::SpanWrappingAndHighlighting;

#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    has $!root-node = tv-node('Root',
                              tv-node('One',
                                      tv-node('One One'),
                                      tv-node('One Two',
                                              tv-node('One Two One'),
                                              tv-node('One Two Two'),
                                              tv-node('One Two Three'))),
                              tv-node('Two',
                                      tv-node('Two One')));

    sub tv-node($text, *@children) {
        Terminal::Widgets::RichTreeViewNode.new(:$text, :@children)
    }

    method initial-layout($builder, $width, $height) {
        my %style;

        with $builder {
            .radio-button(label => 'No Wrap', group => 'wrap-style', id => 'no-wrap', :state(True),
                                   process-input => -> $rb {
                                       with $rb.selected-member {
                                           self!set-wrap(.id);
                                       }
                                       else {
                                           $rb.set-state(True);
                                       }
                                   }),
            .radio-button(label => 'Line Wrap', group => 'wrap-style', id => 'line-wrap',
                                   process-input => -> $rb {
                                       with $rb.selected-member {
                                           self!set-wrap(.id);
                                       }
                                       else {
                                           $rb.set-state(True);
                                       }
                                   }),
            .radio-button(label => 'Word Wrap', group => 'wrap-style', id => 'word-wrap',
                                   process-input => -> $rb {
                                       with $rb.selected-member {
                                           self!set-wrap(.id);
                                       }
                                       else {
                                           $rb.set-state(True);
                                       }
                                   }),
            .checkbox(    label => 'Highlight Selected Line',
                                   process-input => -> $cb {
                                       %.by-id<tree>.set-highlight-line($cb.state);
                                   }),
            .checkbox(    label => 'Show Cursor',
                                   process-input => -> $cb {
                                       %.by-id<tree>.set-show-cursor($cb.state);
                                   }),
            .node(
                .button(  label => 'Quit',
                                   process-input  => { $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node(
                .with-scrollbars(
                    .tree-view(id => 'tree', style => %(set-w => 50),
                               process-click => -> $id, $x, $y {
                                      my $click-log = %.by-id<click-log>;
                                      $click-log.add-entry: "Click on node $id $x:$y \n";
                                      $click-log.refresh-for-scroll;
                                  }),
                ),
                .spacer(),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .with-scrollbars(.log-viewer(id => 'click-log')),
        }
    }

    method !set-wrap($style) {
        my %styles = (
            no-wrap => NoWrap,
            line-wrap => LineWrap,
            word-wrap => WordWrap,
        );
        %.by-id<tree>.set-wrap(%styles{$style});
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        %.by-id<tree>.set-root-node($!root-node);
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', FormUI, title => 'TreeView Example');
}
