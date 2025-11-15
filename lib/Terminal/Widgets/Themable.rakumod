# ABSTRACT: Roles for widgets that can be themed with colors/attributes

use Terminal::Widgets::ColorTheme;


#| Has standard themable states
role Terminal::Widgets::ThemableStates {
    has Bool:D $.enabled = True;

    # Set enabled flag, then refresh to pick up likely visual change
    method set-enabled(Bool:D $!enabled = True) { self.full-refresh }
    method toggle-enabled()                     { self.set-enabled(!$!enabled) }

    #| Determine current active states affecting theming choices
    method current-theme-states() {
        my $toplevel = self.toplevel;
        my $terminal = $toplevel.terminal;
        my $focused  = $toplevel.focused-widget === self;
        my $blurred  = $focused && !($toplevel.is-current-toplevel &&
                                     $terminal.terminal-focused);

        my %states   = :$focused, :$blurred, disabled => !$.enabled;
    }
}


#| Can be themed with a ColorSet
role Terminal::Widgets::Themable
does Terminal::Widgets::ThemableStates {
    #| Colorset that applies to this Themable widget, defaulting to terminal's
    has Terminal::Widgets::ColorSet:D $.colorset = self.terminal.colorset;

    #| Overrides for colorset settings if needed
    has %.color;


    #| Install color overrides; intended to be called at TWEAK time
    method init-themable() {
        $!colorset .= clone(|%!color) if %!color;
    }

    #| Determine proper color based on state variables, taking care to handle
    #| whatever color style mixtures have been requested
    method current-color($states = self.current-theme-states) {
        $.colorset.current-color($states)
    }
}
