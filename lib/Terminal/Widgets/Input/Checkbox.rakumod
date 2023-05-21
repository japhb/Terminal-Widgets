# ABSTRACT: A single checkbox, optionally labeled

use Terminal::Widgets::Input::Boolean;
use Terminal::Widgets::Input::Labeled;


#| A single optionally labeled checkbox
class Terminal::Widgets::Input::Checkbox
 does Terminal::Widgets::Input::Boolean
 does Terminal::Widgets::Input::Labeled {
    #| Checkbox glyphs
    method checkbox-text() {
        my constant %boxes =
            ASCII => « '[ ]' [x] »,
            Uni1  => «   ☐    ☒  »,
            Uni7  => «   🞏    🞕  »;

        self.terminal.caps.best-symbol-choice(%boxes)[+$.state]
    }

    #| Refresh just the value, without changing anything else
    method refresh-value(Bool:D :$print = True) {
        $.grid.set-span-text(0, 0, self.checkbox-text);
        self.composite(:$print);
    }

    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        my $text = self.checkbox-text ~ (' ' ~ $.label if $.label);

        $.grid.clear;
        $.grid.set-span(0, 0, $text, self.current-color);
        self.composite(:$print);
    }
}
