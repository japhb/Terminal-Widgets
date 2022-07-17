# ABSTRACT: Simple form UI example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    method initial-layout($builder, $width, $height) {
        with $builder {
            .checkbox(    extra => \( label => "It's a checkbox" )),
            .checkbox(    extra => \( label => "It's another checkbox" )),
            .radio-button(extra => \( label => "It's a radio button",
                                      group => 'my-radios')),
            .radio-button(extra => \( label => "It's a second radio button",
                                      group => 'my-radios')),
            .text-input(set-h => Nil),
            .button(extra => \( label => 'quit', on-click => { self.quit })),
        }
    }

    method quit() { $.terminal.control.send: 'done' }
}


sub MAIN() {
    first-screen('form', FormUI, title => 'Form UI Example').start;
}
