# ABSTRACT: A simple toggle button (looks like a button, acts like a checkbox)

use Terminal::Capabilities;
constant Uni1 = Terminal::Capabilities::SymbolSet::Uni1;

use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::Input::Boolean;


#| A simple toggle button (looks like a button, acts like a checkbox)
class Terminal::Widgets::Input::ToggleButton
 does Terminal::Widgets::Input::Boolean {
    #| Compute minimum content width for requested style and attributes
    method min-width(:$locale!, :%style!, :$label = '') {
        my $bw         = %style<border-width>;
        my $has-border = $bw ~~ Positional ?? $bw.grep(?*) !! ?$bw;
        $locale.width($label) + 2 * !$has-border
        + 2 # XXXX: Waiting on upgrade to content model
    }

    #| Content (text inside framing)
    method content-text($label) {
        my $has-border = self.layout.computed.has-border;
        my $symbol-set = self.terminal.caps.symbol-set;
        my $string     = $label // '';

        my $text = $has-border         ??       $string       !!
                   $symbol-set >= Uni1 ?? '⌈' ~ $string ~ '⌋' !!
                                          '[' ~ $string ~ ']';

        # XXXX: Waiting on upgrade to content model
        # $.state ?? span('white on_blue', $text) !! $text
        $.state ?? '>' ~ $text ~ '<' !! $text
    }
}
