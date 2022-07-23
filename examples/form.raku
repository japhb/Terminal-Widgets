# ABSTRACT: Simple form UI example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    has Form:D $.form .= new;

    method initial-layout($builder, $width, $height) {
        with $builder {
            .checkbox(    :$.form, label => "It's a checkbox"),
            .checkbox(    :$.form, label => "It's another checkbox"),
            .radio-button(:$.form, label => "It's a radio button",
                                   group => 'my-radios'),
            .radio-button(:$.form, label => "It's a second radio button",
                                   group => 'my-radios'),
            .text-input(  :$.form),
            .node(
                .button(  :$.form, label => 'Show State',
                                   process-input => { self.show-state }),
                .button(  :$.form, label => 'Quit',
                                   process-input => { $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node,  # To soak up extra vertical space
        }
    }

    method show-state() {
        for $.form.inputs {
            .note;
        }
    }
}


sub MAIN() {
    first-screen('form', FormUI, title => 'Form UI Example').start;
}
