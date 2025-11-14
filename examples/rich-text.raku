# ABSTRACT: Demonstrate the rich text widget

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::RichText;
use Terminal::Widgets::SpanWrappingAndHighlighting;

#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    has        $!text = "😂😂😂😂😂😂😂😂 Some not so short demo text. This text is deliberately long, so one can test line wrapping without having to type in so much text first. So here is some more to really hit home and be sure that we definitely have enough text to fill a line even on very wide screen displays and very small fonts. We'll see if someone speaks up and says that this text is not long enough on their setup to test line wrapping. Here are some more duowidth chars: 😂😂😂😂😂😂😂😂😂😂😂😂 \n0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890";

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
                                       %.by-id<text>.set-highlight-line($cb.state);
                                   }),
            .checkbox(    label => 'Show Cursor',
                                   process-input => -> $cb {
                                       %.by-id<text>.set-show-cursor($cb.state);
                                   }),
            .text-input(  process-input => -> $text {
                                       $!text ~= "\n" ~ $text;
                                       %.by-id<text>.set-text($!text);
                                   }),
            .node(
                .button(  label => 'Quit',
                                   process-input  => { $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node(
                .with-scrollbars(
                    .rich-text(id => 'text', style => %(set-w => 50),
                               process-click => -> $line, $x, $y {
                                      my $click-log = %.by-id<click-log>;
                                      $click-log.add-entry: "Click on line $line:$x,$y\n";
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
        %.by-id<text>.set-wrap(%styles{$style});
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        %.by-id<text>.set-text($!text);
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', FormUI, title => 'RichText Example');
}
