# ABSTRACT: Base role for widgets that can be focused / interacted with

use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::ColorTheme;


role Terminal::Widgets::Focusable {
    has Bool:D $.enabled = True;
    has        %.color;

    has Terminal::Widgets::ColorSet:D $.colorset = self.terminal.colorset;


    # Input-specific gist flags
    method gist-flags() {
       |callsame,
       ('FOCUSED' if self.toplevel.focused-widget === self),
       ('enabled' if $!enabled),
    }

    # Make sure unset colors are defaulted, and optionally add input to a form
    method init-focusable() {
        $!colorset .= clone(|%!color) if %!color;
    }

    #| Determine proper color based on state variables, taking care to handle
    #| whatever color style mixtures have been requested
    method current-color($states = self.current-color-states) {
        $.colorset.current-color($states)
    }

    #| Determine current active states affecting color choices
    method current-color-states() {
        my $toplevel = self.toplevel;
        my $terminal = $toplevel.terminal;
        my $focused  = $toplevel.focused-widget === self;
        my $blurred  = $focused && !($toplevel.is-current-toplevel &&
                                     $terminal.terminal-focused);

        my %states = :text, :input, :$focused, :$blurred,
                     disabled => !$.enabled;
    }

    # Set enabled flag, then refresh
    method set-enabled(Bool:D $!enabled = True) { self.full-refresh }
    method toggle-enabled()                     { self.set-enabled(!$!enabled) }

    # Move focus to next or previous Input
    method focus-next-input() {
        with self.next-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
        orwith self.toplevel.first-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
    }
    method focus-prev-input() {
        with self.prev-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
        orwith self.toplevel.last-widget(Terminal::Widgets::Focusable) {
            self.toplevel.focus-on($_)
        }
    }
}
