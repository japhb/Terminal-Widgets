# ABSTRACT: Basic "Hello, World!" example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;

#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class HelloUI is TopLevel {

    #| Define the initial UI layout when the TopLevel first starts up
    method initial-layout($builder, $width, $height) {

        # Use the layout builder to add a PlainText widget and a quit button,
        # centered in the terminal window and taking minimal space.
        with $builder {
            .center(:vertical, style => %(:minimize-h, :minimize-w),
                     .plain-text(text => 'Hello, World!', color => 'bold',
                                 style => %(border-width  => 1,
                                            margin-width  => (0,0,1,0),
                                            padding-width => (0,1,2,3))),
                     .button(label => 'Quit',
                             style => %(border-width => 1),
                             process-input => { $.terminal.quit }),
                    )
        }
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::Simple::App and jump right to the main screen
    App.new.boot-to-screen('hello-world', HelloUI, title => 'Hello');
}
