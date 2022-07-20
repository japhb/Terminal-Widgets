# ABSTRACT: Simple form UI example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    method initial-layout($builder, $width, $height) {
        with $builder {
            .checkbox(    label => "It's a checkbox"),
            .checkbox(    label => "It's another checkbox"),
            .radio-button(label => "It's a radio button",
                          group => 'my-radios'),
            .radio-button(label => "It's a second radio button",
                          group => 'my-radios'),
            .text-input(  style => %(set-h => UInt)),
            .button(      label => 'quit', on-click => { $.terminal.quit }),
        }
    }
}


sub MAIN() {
    first-screen('form', FormUI, title => 'Form UI Example').start;
}
