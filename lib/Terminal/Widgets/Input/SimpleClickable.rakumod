# ABSTRACT: Base for labeled inputs whose only interaction is click/press/select

use Terminal::Widgets::Events;
use Terminal::Widgets::Input;
use Terminal::Widgets::Input::Labeled;


#| Base for labeled input widgets that can only be clicked/pressed/selected
role Terminal::Widgets::Input::SimpleClickable
does Terminal::Widgets::Input
does Terminal::Widgets::Input::Labeled {
    # REQUIRED METHODS

    #| Perform click/press/select/activate action
    method click() { ... }

    #| Format the text in the widget's content area
    method content-text($label) { ... }


    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-frame;
        self.composite(:$print);
    }

    #| Draw framing and full input
    method draw-frame() {
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;

        # XXXX: Temporary hack
        my $label  = $.terminal.locale.plain-text($.label);

        self.draw-framing;
        $.grid.set-span($x, $y, self.content-text($label), self.current-color);
    }

    #| Handle minimal keyboard events
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
            # Allow navigation always, but only click/activate if enabled
            when 'click'      { self.click if $.enabled }
            when 'next-input' { self.focus-next-input }
            when 'prev-input' { self.focus-prev-input }
        }
    }

    #| Handle basic mouse click event
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Always focus on mouse click, but only perform click action if enabled
        self.toplevel.focus-on(self);
        self.click if $.enabled;
    }
}
