# ABSTRACT: A single radio button, optionally labeled

use Terminal::Widgets::I18N::Translation;
use Terminal::Widgets::Input::Boolean;
use Terminal::Widgets::Input::Labeled;


#| A single optionally labeled radio button
class Terminal::Widgets::Input::RadioButton
   is Terminal::Widgets::Input::GroupedBoolean
 does Terminal::Widgets::Input::Labeled {
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
