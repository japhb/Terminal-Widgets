# ABSTRACT: Form UI example with large responsively-sized scrolling menu

use Terminal::Widgets::Simple;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class FormUI is TopLevel {
    has Form:D $.form .= new;

    method initial-layout($builder, $width, $height) {
        # NOTE: To see the effect of box model styling, try these:
        # my %style = padding-width => [0, 2],
        #             border-width  => 1,
        #             margin-width  => 1;
        my %style;

        # NOTE: Resize terminal to see effect of min-h and max-h on the menu
        my %menu-style = |%style, min-h => 10, max-h => 20;
        my @items = (1..100).map({ %(title => "Item $_",
                                     color => ~(16 + $_)) });

        with $builder {
            .menu(:$.form, style => %menu-style, items => @items),
            .node(
                .button(:$.form, :%style, label => 'Show State',
                                 process-input  => { self.show-state }),
                .button(:$.form, :%style, label => 'Quit',
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
