# ABSTRACT: A single radio button, optionally labeled

use Text::MiscUtils::Layout;

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

    #| Radio button glyphs for current state
    method button-text($caps = self.terminal.caps) {
        self.buttons($caps)[+$.state]
    }

    #| Refresh just the value, without changing anything else
    method refresh-value(Bool:D :$print = True) {
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;

        my $text = self.button-text;
        $.grid.set-span-text($x, $y, $text);
        self.add-dirty-rect($x, $y, duospace-width($text), 1);
        self.composite(:$print);
    }

    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-frame;
        self.composite(:$print);
    }

    #| Draw framing and full input
    method draw-frame() {
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;
        my $label  = $.label ~~ TranslatableString
                     ?? ~$.terminal.locale.translate($.label) !! ~$.label;
        my $text   = self.button-text ~ (' ' ~ $label if $label);

        self.draw-framing;
        $.grid.set-span($x, $y, $text, self.current-color);
    }
}
