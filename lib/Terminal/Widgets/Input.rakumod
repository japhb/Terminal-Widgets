# ABSTRACT: Base role for input field widgets

use Terminal::Widgets::Widget;


role Terminal::Widgets::Input
  is Terminal::Widgets::Widget {
    has Bool:D $.enabled = True;

    # Required methods
    method refresh-value { ... }  # Refresh display for input value changes ONLY
    method full-refresh  { ... }  # Refresh display of entire input

    # Set enabled flag, then refresh
    method set-enabled(Bool:D $!enabled = True) { self.full-refresh }
    method toggle-enabled()                     { self.set-enabled(!$!enabled) }
}
