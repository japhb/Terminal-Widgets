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
    has Bool:D $!active = False;   # XXXX: Handle this for all inputs?

    has Terminal::Widgets::Form $.form;


    # OPTIONAL OPTIMIZATION: Refresh display for input value changes ONLY
    # XXXX: Variants for color changes versus metrics changes?
    method refresh-value(Bool:D :$print = True) {
        # Default to just doing a full-refresh
        self.full-refresh(:$print)
    }


    #| Add input to a form if assigned
    submethod TWEAK() {
        .add-input(self) with $!form;
    }

    # Add Input-specific gist flags
    method gist-flags() {
       |self.Terminal::Widgets::Focusable::gist-flags,
       ('ACTIVE'  if $!active),
       ('ERROR'   if $!error),
       ('hint-target:' ~ $!hint-target.gist if $!hint-target),
    }

    #| Determine current active states affecting color choices
    method current-color-states() {
        my $terminal = self.toplevel.terminal;
        my $active   = $!active && $terminal.ui-prefs<input-activation-flash>;

        my %states   = |callsame,
                       :text, :input, :$active, error => ?$.error;
    }

    #| Set the hint to a plain Str
    multi method set-hint(Str:D $hint) {
        my $target = $.hint-target;
           $target = self.toplevel.by-id{$target} if $target ~~ Str:D;

        # XXXX: Defang the hint text?
        $target.?set-text($hint) if $target;
    }

    #| Set the hint to general TextContent
    multi method set-hint($hint) {
        self.set-hint($.terminal.locale.plain-text($hint))
    }

    #| Set error state, then refresh
    #  XXXX: error-target and human-friendly error display?
    method set-error($!error) { self.full-refresh }

    #| Make sure hint updated when taking focus
    multi method handle-event(Terminal::Widgets::Events::TakeFocus:D $event, AtTarget) {
        self.Terminal::Widgets::Widget::handle-event($event, AtTarget);
        self.set-hint($.hint) if $.hint.defined;
    }
}
