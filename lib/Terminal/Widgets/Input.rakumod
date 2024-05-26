# ABSTRACT: Base role for input field widgets

use Terminal::Widgets::Events;
use Terminal::Widgets::Form;
use Terminal::Widgets::Focusable;


role Terminal::Widgets::Input
does Terminal::Widgets::Focusable {
    has        &.process-input;
    has        $.hint-target;
    has        $.hint;
    has        $.error;
    has Bool:D $!active  = False;   # XXXX: Handle this for all inputs?

    has Terminal::Widgets::Form       $.form;


    # Input-specific gist flags
    method gist-flags() {
       |callsame,
       ('ACTIVE'  if $!active),
       ('ERROR'   if $!error),
       ('hint-target:' ~ $!hint-target.gist if $!hint-target),
    }


    # Refresh methods

    # REQUIRED: Refresh display of entire input
    method full-refresh { ... }

    # OPTIONAL OPTIMIZATION: Refresh display for input value changes ONLY
    # XXXX: Variants for color changes versus metrics changes?
    method refresh-value(Bool:D :$print = True) {
        # Default to just doing a full-refresh
        self.full-refresh(:$print)
    }


    # Make sure unset colors are defaulted, and optionally add input to a form
    submethod TWEAK() {
        self.init-focusable;
        .add-input(self) with $!form;
    }

    #| Determine current active states affecting color choices
    method current-color-states() {
        my $toplevel = self.toplevel;
        my $terminal = $toplevel.terminal;
        my $focused  = $toplevel.focused-widget === self;
        my $blurred  = $focused && !($toplevel.is-current-toplevel &&
                                     $terminal.terminal-focused);
        my $active   = $!active && $terminal.ui-prefs<input-activation-flash>;

        my %states = :text, :input, :$focused, :$blurred, :$active,
                     error => ?$.error, disabled => !$.enabled;
    }

    #| Set the hint to a plain Str
    multi method set-hint(Str:D $hint) {
        my $target = $.hint-target;
           $target = self.toplevel.by-id{$target} if $target ~~ Str:D;

        # XXXX: Defang the hint text?
        $target.?set-text($hint) if $target;
    }

    #| Set the hint to a translatable
    multi method set-hint($hint) {
        self.set-hint($.terminal.locale.plain-text($hint))
    }

    # Set error state, then refresh
    # XXXX: error-target and human-friendly error display?
    method set-error($!error) { self.full-refresh }

    # Handle taking focus
    multi method handle-event(Terminal::Widgets::Events::TakeFocus:D $event, AtTarget) {
        self.Terminal::Widgets::Widget::handle-event($event, AtTarget);
        self.set-hint($.hint) if $.hint.defined;
    }
}
