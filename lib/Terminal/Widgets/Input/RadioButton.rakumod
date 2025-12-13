# ABSTRACT: A single radio button, optionally labeled

use Terminal::Widgets::TextContent;
use Terminal::Widgets::Layout;
use Terminal::Widgets::Input::Boolean;


#| A single optionally labeled radio button
class Terminal::Widgets::Input::RadioButton
   is Terminal::Widgets::Input::GroupedBoolean {
    method layout-class() { Terminal::Widgets::Layout::RadioButton }

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
        my @label-spans = $.terminal.locale.flat-string-spans($label // '');
        my $button-span = self.buttons()[+$.state];
        span-tree($button-span, |(pad-span(1), |@label-spans if $label))
    }
}


# Register RadioButton as a buildable widget type
Terminal::Widgets::Input::RadioButton.register;
