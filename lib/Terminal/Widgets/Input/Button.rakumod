# ABSTRACT: General clickable button

use Terminal::Capabilities;
constant Uni1 = Terminal::Capabilities::SymbolSet::Uni1;

use Terminal::Widgets::Input::SimpleClickable;


class Terminal::Widgets::Input::Button
 does Terminal::Widgets::Input::SimpleClickable {
    #| Compute minimum content width for requested style and attributes
    method min-width(:$locale!, :%style!, :$label = '') {
        my $bw         = %style<border-width>;
        my $has-border = $bw ~~ Positional ?? $bw.grep(?*) !! ?$bw;
        $locale.width($label) + 2 * !$has-border
    }

    #| Content (text inside framing)
    method content-text($label) {
        my $has-border = self.layout.computed.has-border;
        my $symbol-set = self.terminal.caps.symbol-set;
        my $string     = $label // '';

        $has-border         ??       $string       !!
        $symbol-set >= Uni1 ?? '⌈' ~ $string ~ '⌋' !!
                               '[' ~ $string ~ ']'
    }

    #| Process a click event
    method click(Bool:D :$print = True) {
        $!active = True;
        self.refresh-value(:$print);

        $_(self) with &.process-input;

        $!active = False;
        self.refresh-value(:$print);
    }
}
