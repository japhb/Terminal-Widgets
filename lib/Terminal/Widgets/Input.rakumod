# ABSTRACT: Base role for input field widgets

use Terminal::Widgets::Widget;
use Terminal::Widgets::Utils;


role Terminal::Widgets::Input
  is Terminal::Widgets::Widget {
    has Bool:D $.enabled = True;
    has        $.error;
    has        %.color;

    # Required methods
    method refresh-value { ... }  # Refresh display for input value changes ONLY
    method full-refresh  { ... }  # Refresh display of entire input

    # Make sure unset colors are defaulted
    submethod TWEAK() {
        self.default-colors;
    }

    # Set color defaults
    method default-colors() {
        my constant %defaults =
            error    => 'red',
            disabled => gray-color(.5),
            focused  => 'on_' ~ gray-color(.25),
            default  => 'on_' ~ gray-color(.1),
        ;

        for %defaults.kv -> $state, $color {
            %!color{$state} //= $color;
        }
    }

    #| Determine proper color based on state variables, taking care to handle
    #| whatever color style mixtures have been requested
    method current-color() {
        my $focused = $.parent && $.parent.focused-child === self;

        # Merge all relevant colors into a single list of attribute requests
        my @colors =  %.color<default>,
                     (%.color<focused>  if     $focused),
                     (%.color<disabled> unless $.enabled),
                     (%.color<error>    if     $.error);
        my @split  = @colors.join(' ').words.reverse;

        # If there are any resets, only use the requests after the last reset
        my $reset  = @split.first('reset', :k);
        @split    .= splice($reset) if $reset.defined;

        # Separate background from others
        my $background = @split.first(*.starts-with('on_'));
        my @others     = @split.grep(!*.starts-with('on_')).reverse;

        # Final color info!
        (|@others, $background).join(' ')
    }

    # Set error state, then refresh
    method set-error($!error) { self.full-refresh }

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
