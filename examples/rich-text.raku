# ABSTRACT: Demonstrate the selectable text widget

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;

#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    has Form:D $.form .= new;
    has        $!text = "Some demo text.";

    method initial-layout($builder, $width, $height) {
        my %style;

        with $builder {
            .checkbox(    :$.form, :%style, label => 'Wrap',
                                   process-input => -> $cb {
                                       %.by-id<text>.set-wrap($cb.state);
                                   }),
            .text-input(  :$.form, :%style,
                                   process-input => -> $text {
                                       $!text ~= "\n" ~ $text;
                                       %.by-id<text>.set-text($!text);
                                   }),
            .node(
                .button(  :$.form, :%style, label => 'Quit',
                                   process-input  => { $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node(
                .rich-text(id => 'text', :%style),
                .vscroll(scroll-target => 'text'),
            ),
            .node(
                .hscroll(scroll-target => 'text'),
                .spacer(style => %(set-w => 1, set-h => 1)),
            ),
        }
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        %.by-id<text>.set-text($!text);
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', FormUI, title => 'Form UI Example');
}
