# ABSTRACT: Simple form UI example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;
use Terminal::Widgets::TextContent;


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
            .checkbox(    :$.form, :%style, label => 'It\'s a checkbox'),
            .checkbox(    :$.form, :%style, label => 'It\'s another checkbox'),
            .radio-button(:$.form, :%style, label => 'It\'s a radio button',
                                            group => 'my-radios', id => 'one'),
            .radio-button(:$.form, :%style, label => 'It\'s a second radio button',
                                            group => 'my-radios', id => 'two'),
            .text-input(  :$.form, :%style),
            .node(
                .button(  :$.form, :%style, label => 'Show State',
                                   process-input  => { self.show-state }),
                .button(  :$.form, :%style, label => 'Show Layout Tree',
                                   process-input  => { self.show-layout }),
                .button(  :$.form, :%style, label => 'Quit',
                                   process-input  => { $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .with-scrollbars(
                .log-viewer(id => 'lv', :%style)
            ),
        }
    }

    method show-state() {
        my $log-viewer = %.by-id<lv>;
        $log-viewer.add-entry($?NL) unless $log-viewer.empty;

        for $.form.inputs {
            $log-viewer.add-entry(span-tree(color => 'on_white',
                                            string-span($++ ~ ' ', color => 'red'),
                                            string-span(.gist,     color => 'blue')));
        }

        my $selected = %.by-id<one>.selected-member;
        $log-viewer.add-entry($selected
                              ?? string-span('Radio button ' ~ $selected.id.raku ~ ' selected',
                                             color => 'blue on_white')

                              !! string-span('No radio button selected',
                                             color => 'red on_white'));

        $log-viewer.refresh-for-scroll;
    }

    method show-layout() {
        my $log-viewer = %.by-id<lv>;
        $log-viewer.add-entry($?NL) unless $log-viewer.empty;
        $log-viewer.add-entry(string-span(self.layout.gist, color => 'green'));
        $log-viewer.refresh-for-scroll;
    }
}


sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', FormUI, title => 'Form UI Example');
}
