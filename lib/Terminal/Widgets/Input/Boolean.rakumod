# ABSTRACT: Base role for various boolean-valued input field widgets

use Terminal::Widgets::Input;


role Terminal::Widgets::Input::Boolean
does Terminal::Widgets::Input {
    has Bool:D $.state = False;

    # Set boolean state, then refresh
    method set-state(Bool:D $!state) { self.refresh-value }
    method toggle-state()            { self.set-state(!$!state) }
}
