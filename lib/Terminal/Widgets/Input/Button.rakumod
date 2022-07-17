# ABSTRACT: General clickable button

use Terminal::Widgets::Events;
use Terminal::Widgets::Input;
use Terminal::Widgets::Input::Labeled;


class Terminal::Widgets::Input::Button
 does Terminal::Widgets::Input
 does Terminal::Widgets::Input::Labeled {
    has &.on-click;

    #| Refresh just the "value" (active state)
    method refresh-value(Bool:D :$print = True) {
        # For now, just force a full-refresh
        self.full-refresh(:$print);
    }

    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        # my $text = '[' ~ (self.label || 'Button') ~ ']';
        my $text = '⌈' ~ (self.label || 'Button') ~ '⌋';

        $.grid.clear;
        $.grid.set-span(0, 0, $text, self.current-color);
        self.composite(:$print);
    }

    #| Process a click event
    method click(Bool:D :$print = True) {
        $!active = True;
        self.refresh-value(:$print);

        .(self) with &.on-click;

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
