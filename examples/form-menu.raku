# ABSTRACT: Simple form UI example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    has Form:D $.form .= new;

    method initial-layout($builder, $width, $height) {
        my %style;

        # NOTE: To see the effect of styling, try these:
        # %style = padding-width => [0, 2],
        #          border-width  => 1,
        #          margin-width  => 1;

        with $builder {
            .menu(
              :$.form,
              :%style,
              label => "Select an Item",
              items => [
                { title => 'Item a' },
                { title => 'Item b' },
                { title => 'Item c' },
                { title => 'Item d' },
                { title => 'Item e' },
                { title => 'Item f' },
                { title => 'Item g' },
                { title => 'Item h' },
                { title => 'Item i' }
              ]
            ),
            .node(
                .button(  :$.form, :%style, label => 'Show State',
                                   process-input  => { self.show-state }),
                .button(  :$.form, :%style, label => 'Quit',
                                   process-input  => { $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .log-viewer(id => 'lv', :%style),
        }
    }

    method show-state() {
        my $log-viewer = %.by-id<lv>;
        $log-viewer.add-entry('') if $log-viewer.log;

        for $.form.inputs {
            $log-viewer.add-entry(.gist);
        }
        $log-viewer.full-refresh;
    }
}


sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', FormUI, title => 'Form UI Example');
}
