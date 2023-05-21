# ABSTRACT: General clickable button

use Terminal::Widgets::TerminalCapabilities;
use Terminal::Widgets::Events;
use Terminal::Widgets::Input;
use Terminal::Widgets::Input::Labeled;


class Terminal::Widgets::Input::Button
 does Terminal::Widgets::Input
 does Terminal::Widgets::Input::Labeled {
    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        my $label      = self.label || 'Button';
        my $symbol-set = self.terminal.caps.symbol-set;
        my $text       = $symbol-set >= Uni1 ?? '⌈' ~ $label ~ '⌋'
                                             !! '[' ~ $label ~ ']';
        $.grid.clear;
        $.grid.set-span(0, 0, $text, self.current-color);
        self.composite(:$print);
    }

    #| Process a click event
    method click(Bool:D :$print = True) {
        $!active = True;
        self.refresh-value(:$print);

        $_(self) with &.process-input;

        $!active = False;
        self.refresh-value(:$print);
    }

    # Handle basic events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            ' '          => 'click',
            Ctrl-M       => 'click',  # CR/Enter
            KeypadEnter  => 'click',

            Ctrl-I       => 'next-input',    # Tab
            ShiftTab     => 'prev-input',    # Shift-Tab is weird and special
            ;

        with %keymap{$event.keyname} {
            when 'click'      { self.click }
            when 'next-input' { self.focus-next-input }
            when 'prev-input' { self.focus-prev-input }
        }
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        self.toplevel.focus-on(self);
        self.click;
    }
}
