# ABSTRACT: Simple sparkline example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class SparklineUI is TopLevel {
    method initial-layout($builder, $width, $height) {
        with $builder {
            .push-left(:vertical, style => %( :minimize-w, :minimize-h ),
                .push-right(style => %( :minimize-h ),
                            .sparkline(id => 'small',
                                       style => %(set-h => 1, set-w => 5,
                                                  border-width => 1))),
                .push-right(style => %( :minimize-h ),
                            .sparkline(id => 'wide',
                                       style => %(set-h => 1, set-w => 20,
                                                  border-width => 1))),
                .push-right(style => %( :minimize-h ),
                            .sparkline(id => 'tall',
                                       style => %(set-h => 2, set-w => 5,
                                                  border-width => 1))),
                .push-right(style => %( :minimize-h ),
                            .sparkline(id => 'big',
                                       style => %(set-h => 4, set-w => 20,
                                                  border-width => 1))),
                .button(label => 'Quit', process-input  => { $.terminal.quit }),
            ),
            .spacer,
        }
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        my @data = (^100).roll(20);
        for < small wide tall big > {
            .data.append(@data) with %.by-id{$_};
        }
    }
}


sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the main screen
    App.new.boot-to-screen('sparklines', SparklineUI, title => 'Sparkline Example');
}
