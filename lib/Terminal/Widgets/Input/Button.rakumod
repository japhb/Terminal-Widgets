# ABSTRACT: General clickable button

use Terminal::Capabilities;
constant Uni1 = Terminal::Capabilities::SymbolSet::Uni1;

use Terminal::Widgets::Events;
use Terminal::Widgets::Input;
use Terminal::Widgets::Input::Labeled;


class Terminal::Widgets::Input::Button
 does Terminal::Widgets::Input
 does Terminal::Widgets::Input::Labeled {
    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-frame;
        self.composite(:$print);
    }

    #| Draw framing and button itself
    method draw-frame() {
        my $layout     = self.layout.computed;
        my $x          = $layout.left-correction;
        my $y          = $layout.top-correction;
        my $label      = self.label || 'Button';
        my $symbol-set = self.terminal.caps.symbol-set;
        my $text       = $layout.has-border  ??       $label       !!
                         $symbol-set >= Uni1 ?? '⌈' ~ $label ~ '⌋' !!
                                                '[' ~ $label ~ ']' ;
        self.draw-framing;
        $.grid.set-span($x, $y, $text, self.current-color);
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
