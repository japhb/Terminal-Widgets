# ABSTRACT: Demonstrate the tree view widget

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::TreeView;
use Terminal::Widgets::SpanWrappingAndHighlighting;

#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    has @!trees =
        Terminal::Widgets::RichTreeViewNode.new(text => "One", children => (
            Terminal::Widgets::RichTreeViewNode.new(text => "One One"),
            Terminal::Widgets::RichTreeViewNode.new(text => "One Two", children => (
                Terminal::Widgets::RichTreeViewNode.new(text => "One Two One"),
                Terminal::Widgets::RichTreeViewNode.new(text => "One Two Two"),
                Terminal::Widgets::RichTreeViewNode.new(text => "One Two Three"),
            ))
        )),
        Terminal::Widgets::RichTreeViewNode.new(text => "Two", children => (
            Terminal::Widgets::RichTreeViewNode.new(text => "Two One"),
        )),
        ;

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
                .tree-view(id => 'tree', style => %(max-w => 50),
                                   process-click => -> $node {
                                       my $click-log = %.by-id<click-log>;
                                       $click-log.add-entry: "Click on node {$node.id}\n";
                                       $click-log.refresh-for-scroll;
                                   }),
                .vscroll(scroll-target => 'tree'),
                .spacer(),
            ),
            .node(
                .hscroll(scroll-target => 'tree'),
                .spacer(style => %(set-w => 1, set-h => 1)),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node(
                .log-viewer(id => 'click-log'),
                .vscroll(scroll-target => 'click-log'),
            ),
            .node(
                .hscroll(scroll-target => 'click-log'),
                .spacer(style => %(set-w => 1, set-h => 1)),
            ),
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
        %.by-id<tree>.set-trees(@!trees);
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', FormUI, title => 'TreeView Example');
}
