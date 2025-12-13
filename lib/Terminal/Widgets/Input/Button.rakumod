# ABSTRACT: General clickable button

use Terminal::Capabilities;
constant Uni1 = Terminal::Capabilities::SymbolSet::Uni1;

use Terminal::Widgets::TextContent;
use Terminal::Widgets::Layout;
use Terminal::Widgets::Input::SimpleClickable;


#| Layout node for a button input widget
class Terminal::Widgets::Layout::Button
   is Terminal::Widgets::Layout::SingleLineInput {
    method builder-name() { 'button' }
    method input-class()  { ::('Terminal::Widgets::Input::Button') }
}


class Terminal::Widgets::Input::Button
 does Terminal::Widgets::Input::SimpleClickable {
    method layout-class() { Terminal::Widgets::Layout::Button }

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
        span-tree(|@spans);
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


# Register Button as a buildable widget type
Terminal::Widgets::Input::Button.register;
