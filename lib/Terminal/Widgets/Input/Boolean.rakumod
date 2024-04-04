# ABSTRACT: Base role for various boolean-valued input field widgets

use Terminal::Widgets::Events;
use Terminal::Widgets::Input;


role Terminal::Widgets::Input::Boolean
does Terminal::Widgets::Input {
    has Bool:D $.state = False;

    # Boolean-specific gist flags
    method gist-flags() {
        |self.Terminal::Widgets::Input::gist-flags,
        'state:' ~ $!state
    }

    # Set boolean state, then refresh
    method set-state(Bool:D $!state) { self.refresh-value;
                                       $_(self) with &.process-input; }
    method toggle-state()            { self.set-state(!$!state) }

    # Handle basic events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            ' '          => 'toggle-state',
            Ctrl-M       => 'toggle-state',  # CR/Enter
            KeypadEnter  => 'toggle-state',

            Ctrl-I       => 'next-input',    # Tab
            ShiftTab     => 'prev-input',    # Shift-Tab is weird and special
            ;

        with %keymap{$event.keyname} {
            # Allow navigation always, but only change state if enabled
            when 'toggle-state' { self.toggle-state if $.enabled }
            when 'next-input'   { self.focus-next-input }
            when 'prev-input'   { self.focus-prev-input }
        }
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Always focus on click, but only change state if enabled
        self.toplevel.focus-on(self);
        self.toggle-state if $.enabled;
    }
}
