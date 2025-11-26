# ABSTRACT: A single checkbox, optionally labeled

use Terminal::Widgets::TextContent;
use Terminal::Widgets::Input::Boolean;


#| A single optionally labeled checkbox
class Terminal::Widgets::Input::Checkbox
 does Terminal::Widgets::Input::Boolean {
    #| Compute minimum content width for requested style and attributes
    method min-width(:$locale!, :$context!, :$label = '') {
        my @boxes  = self.checkboxes($context.caps);
        my $maxbox = @boxes.map({ $locale.width($_) }).max;

        $maxbox + ?$label + $locale.width($label)
    }

    #| Checkbox glyphs for given terminal capabilities
    method checkboxes($caps = self.terminal.caps) {
        my constant %boxes =
            ASCII => « '[ ]' [x] »,
            Uni1  => «   ☐    ☒  »,
            Uni7  => «   🞏    🞕  »;

        $caps.best-symbol-choice(%boxes)
    }

    #| Content (text inside framing)
    method content-text($label) {
        my @label-spans = $.terminal.locale.flat-string-spans($label // '');
        my $box-span    = self.checkboxes()[+$.state];
        span-tree($box-span, |(pad-span(1), |@label-spans if $label))
    }
}
