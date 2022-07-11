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

    # Convert animation drawing to full-refresh
    method draw-frame() {
        self.full-refresh;
        callsame;
    }

    # Move focus to next or previous Input
    method focus-next-input() {
        self.toplevel.focus-on($_) with self.next-widget(Terminal::Widgets::Input)
    }
    method focus-prev-input() {
        self.toplevel.focus-on($_) with self.prev-widget(Terminal::Widgets::Input)
    }
}
