# ABSTRACT: Simple two-page form UI example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;


#| Second form page, able to display selections or return to the previous page
class Form2UI is TopLevel {
    has @.items     is required;
    has $.prev-page is required;
    has Form $.form .= new;

    method initial-layout($builder, $width, $height) {
        with $builder {
            .plain-text(text  => 'Please select another item',
                        style => %(margin-width => [0, 0, 1, 0], :minimize-h)),
            .menu(:$.form, id => 'menu', :@.items, style => %(max-h => 20)),
            .node(
                .button(:$.form, label => 'Select Second Item',
                        process-input  => { self.show-selections }),
                .button(:$.form, label => 'Return to First Page',
                        process-input  => { $.terminal.set-toplevel($.prev-page) }),
                .button(:$.form, label => 'Quit',
                        process-input  => { $.terminal.quit }),
            ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .log-viewer(id => 'lv'),
        }
    }

    method show-selections() {
        my $menu1   = $.prev-page.by-id<menu>;
        my $menu2   = %.by-id<menu>;
        my $select1 = $menu1.items[$menu1.selected];
        my $select2 = $menu2.items[$menu2.selected];

        my $log-viewer = %.by-id<lv>;
        $log-viewer.add-entry("First selection:  $select1<title>");
        $log-viewer.add-entry("Second selection: $select2<title>");
        $log-viewer.full-refresh;
    }
}


#| First form page, able to make a single selection and move to the next page
class FormUI is TopLevel {
    has @.items     is required;
    has Form $.form .= new;

    method initial-layout($builder, $width, $height) {
        with $builder {
            .plain-text(text  => 'Select an Item',
                        style => %(margin-width => [0, 0, 1, 0], :minimize-h)),
            .menu(:$.form, id => 'menu', :@.items, style => %(max-h => 20)),
            .node(
                .button(:$.form, label => 'Select First Item',
                        process-input  => { self.goto-page2 }),
                .button(:$.form, label => 'Quit',
                        process-input  => { $.terminal.quit }),
            ),
        }
    }

    method goto-page2() {
        my $page2-ui = Form2UI.new(:$.x, :$.y, :$.w, :$.h, :$.terminal,
                                   :@.items, prev-page => self);
        $.terminal.set-toplevel($page2-ui);
    }
}


sub MAIN() {
    # Define a menu item list to be used for both form pages
    my @items = ('Item ' «~« <a b c d e f g>).map({ %(title => $_) });

    # Boot a Terminal::Widgets::App and jump right to the first form screen
    App.new.boot-to-screen('page1', FormUI, title => 'Form Page 1', :@items);
}
