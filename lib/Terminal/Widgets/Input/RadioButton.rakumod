# ABSTRACT: A single radio button, optionally labeled

use Terminal::Widgets::I18N::Translation;
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

    #| All buttons in this button's group
    method group-members() {
        self.toplevel.group-members($!group)
    }

    #| Selected member of this button's group
    method selected-member() {
        self.group-members.first(*.state)
    }

    #| If setting this button, unset remainder in group
    method set-state(Bool:D $state) {
        self.Terminal::Widgets::Input::Boolean::set-state($state);
        if $state {
            .set-state(False) for self.group-members.grep(* !=== self);
        }
    }

    #| Compute minimum content width for requested style and attributes
    method min-width(:$locale!, :$context!, :$label = '') {
        my @buttons   = self.buttons($context.caps);
        my $maxbutton = @buttons.map({ $locale.width($_) }).max;

        $maxbutton + ?$label + $locale.width($label)
    }

    #| Radio button glyphs for given terminal capabilities
    method buttons($caps = self.terminal.caps) {
        my constant %buttons =
            ASCII => « '( )' (*) »,
            Uni1  => «   ○    ⊙  »,
            Uni7  => «   🞅    🞊  »;

        $caps.best-symbol-choice(%buttons)
    }

    #| Content (text inside framing)
    method content-text($label) {
        self.buttons()[+$.state] ~ (' ' ~ $label if $label)
    }
}
