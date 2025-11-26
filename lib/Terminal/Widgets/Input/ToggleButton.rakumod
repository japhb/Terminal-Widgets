# ABSTRACT: A simple toggle button (looks like a button, acts like a checkbox)

use Terminal::Capabilities;
constant Uni1 = Terminal::Capabilities::SymbolSet::Uni1;

use Terminal::Widgets::TextContent;
use Terminal::Widgets::Input::Boolean;


#| A simple toggle button (looks like a button, acts like a checkbox)
class Terminal::Widgets::Input::ToggleButton
 does Terminal::Widgets::Input::Boolean {
    #| Compute minimum content width for requested style and attributes
    method min-width(:$locale!, :%style!, :$label = '') {
        my $bw         = %style<border-width>;
        my $has-border = $bw ~~ Positional ?? $bw.grep(?*) !! ?$bw;
        $locale.width($label) + 2 * !$has-border
    }

    #| Content (text inside framing)
    method content-text($label) {
        my $terminal   = self.terminal;
        my $symbol-set = $terminal.caps.symbol-set;
        my $has-Uni1   = $symbol-set >= Uni1;
        my $locale     = $terminal.locale;

        my $has-border = self.layout.computed.has-border;
        my @string     = $locale.flat-string-spans($label // '');
        my @spans      = $has-border ??        @string       !!
                         $has-Uni1   ?? ('⌈', |@string, '⌋') !!
                                        ('[', |@string, ']');

        $.state ?? span-tree(color => 'white on_blue', |@spans)
                !! span-tree(|@spans)
    }
}
