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
            .log-viewer,
        }
    }

    method show-state() {
        use Terminal::Widgets::Viewer::Log;
        my $log-viewer = @.children.first(Terminal::Widgets::Viewer::Log);
        $log-viewer.add-entry('') if $log-viewer.log;

        for $.form.inputs {
            $log-viewer.add-entry(.gist);
        }
        $log-viewer.full-refresh;
    }
}


sub MAIN() {
    first-screen('form', FormUI, title => 'Form UI Example').start;
}
