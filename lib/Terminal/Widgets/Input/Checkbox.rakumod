# ABSTRACT: A single checkbox, optionally labeled

use Terminal::Widgets::I18N::Translation;
use Terminal::Widgets::Input::Boolean;
use Terminal::Widgets::Input::Labeled;


#| A single optionally labeled checkbox
class Terminal::Widgets::Input::Checkbox
 does Terminal::Widgets::Input::Boolean
 does Terminal::Widgets::Input::Labeled {
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

    #| Checkbox glyphs for current state
    method checkbox-text($caps = self.terminal.caps) {
        self.checkboxes($caps)[+$.state]
    }

    #| Refresh just the value, without changing anything else
    method refresh-value(Bool:D :$print = True) {
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;

        my $text = self.checkbox-text;
        $.grid.set-span-text($x, $y, $text);
        self.add-dirty-rect($x, $y, $.terminal.locale.width($text), 1);
        self.composite(:$print);
    }

    #| Draw framing and full input
    method draw-frame() {
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;
        my $label  = $.label ~~ TranslatableString
                     ?? ~$.terminal.locale.translate($.label) !! ~$.label;
        my $text   = self.checkbox-text ~ (' ' ~ $label if $label);

        self.draw-framing;
        $.grid.set-span($x, $y, $text, self.current-color);
    }
}
