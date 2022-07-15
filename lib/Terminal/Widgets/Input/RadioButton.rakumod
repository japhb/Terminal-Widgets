# ABSTRACT: A single radio button, optionally labeled

use Terminal::Widgets::Input::Boolean;
use Terminal::Widgets::Input::Labeled;


#| A single optionally labeled radio button
class Terminal::Widgets::Input::RadioButton
 does Terminal::Widgets::Input::Boolean
 does Terminal::Widgets::Input::Labeled {
    has Str:D $.group is required;

    #| Make sure radio button is added to group within toplevel
    submethod TWEAK() {
        self.Terminal::Widgets::Input::TWEAK;
        self.toplevel.add-to-group(self, $!group);
    }

    #| If setting this button, unset remainder in group
    method set-state(Bool:D $state) {
        self.Terminal::Widgets::Input::Boolean::set-state($state);
        if $state {
            my @others = self.toplevel.named-group{$.group}.grep(* !=== self);
            .set-state(False) for @others;
        }
    }

    #| Radio button glyphs
    method button-text() {
        # $.state ?? '(*)' !! '( )'
        $.state ?? '🞊' !! '🞅';
    }

    #| Refresh just the value, without changing anything else
    method refresh-value(Bool:D :$print = True) {
        $.grid.set-span-text(0, 0, self.button-text);
        self.composite(:$print);
    }

    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        my $text = self.button-text ~ (' ' ~ $.label if $.label);

        $.grid.clear;
        $.grid.set-span(0, 0, $text, self.current-color);
        self.composite(:$print);
    }
}
