# ABSTRACT: A single radio button, optionally labeled

use Terminal::Widgets::Input::Boolean;
use Terminal::Widgets::Input::Labeled;


#| A single optionally labeled radio button
class Terminal::Widgets::Input::RadioButton
 does Terminal::Widgets::Input::Boolean
 does Terminal::Widgets::Input::Labeled {
    #| Radio button glyphs
    method button-text() {
        # $.state ?? '(*)' !! '( )'
        $.state ?? '🞊' !! '🞅';
    }

    #| Refresh just the value, without changing anything else
    method refresh-value(Bool:D :$print = True) {
        $.grid.set-span-text(0, 0, self.button-text);
        self.compose(:$print);
    }

    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        my $text = self.button-text ~ (' ' ~ $.label if $.label);

        $.grid.clear;
        $.grid.set-span-text(0, 0, $text);
        self.compose(:$print);
    }
}
