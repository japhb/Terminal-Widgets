# ABSTRACT: Base role for input field widgets

use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::Events;
use Terminal::Widgets::Widget;
use Terminal::Widgets::Form;


role Terminal::Widgets::Input
  is Terminal::Widgets::Widget {
    has Bool:D $.enabled = True;
    has Bool:D $!active  = False;   # XXXX: Handle this for all inputs?
    has        &.process-input;
    has        $.hint-target;
    has        $.hint;
    has        $.error;
    has        %.color;

    has Terminal::Widgets::Form $.form;


    # Input-specific gist flags
    method gist-flags() {
       |callsame,
       ('ERROR'   if $!error),
       ('ACTIVE'  if $!active),
       ('FOCUSED' if self.toplevel.focused-widget === self),
       ('enabled' if $!enabled),
       ("hint-target:$!hint-target.gist()" if $!hint-target),
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
        self.default-colors;
        .add-input(self) with $!form;
    }

    # Set color defaults
    method default-colors() {
        my constant %defaults =
            error     => 'red',
            disabled  => gray-color(.5e0),
            active    => 'bold inverse',
            highlight => 'bold white on_blue',
            blurred   => 'on_' ~ gray-color(.25e0),
            focused   => 'on_' ~ rgb-color(.2e0, .2e0, 0e0),  # Dim yellow
            default   => 'on_' ~ gray-color(.1e0),
        ;

        for %defaults.kv -> $state, $color {
            %!color{$state} //= $color;
        }
    }

    #| Determine proper color based on state variables, taking care to handle
    #| whatever color style mixtures have been requested
    method current-color() {
        my $toplevel = self.toplevel;
        my $focused  = $toplevel.focused-widget === self;
        my $blurred  = $focused && !($toplevel.is-current-toplevel &&
                                     $toplevel.terminal.terminal-focused);

        # Merge all relevant colors into a single list of attribute requests
        my @colors =  %.color<default>,
                     (%.color<focused>  if     $focused),
                     (%.color<blurred>  if     $blurred),
                     (%.color<active>   if     $!active),
                     (%.color<disabled> unless $.enabled),
                     (%.color<error>    if     $.error);

        color-merge(@colors)
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
        self.set-hint(~$.terminal.locale.translate($hint))
    }

    # Set error state, then refresh
    method set-error($!error) { self.full-refresh }

    # Set enabled flag, then refresh
    method set-enabled(Bool:D $!enabled = True) { self.full-refresh }
    method toggle-enabled()                     { self.set-enabled(!$!enabled) }

    # Convert animation drawing to full-refresh
    method draw-frame() {
        self.full-refresh;
        # XXXX: Do we need to callsame here?
        # callsame;
    }

    # Move focus to next or previous Input
    method focus-next-input() {
        self.toplevel.focus-on($_) with self.next-widget(Terminal::Widgets::Input)
    }
    method focus-prev-input() {
        self.toplevel.focus-on($_) with self.prev-widget(Terminal::Widgets::Input)
    }

    # Handle taking focus
    multi method handle-event(Terminal::Widgets::Events::TakeFocus:D $event, AtTarget) {
        self.Terminal::Widgets::Widget::handle-event($event, AtTarget);
        self.set-hint($.hint) if $.hint.defined;
    }
}
