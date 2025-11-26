# ABSTRACT: Base for labeled inputs whose only interaction is click/press/select

use Terminal::Widgets::Events;
use Terminal::Widgets::Input;
use Terminal::Widgets::Input::Labeled;
use Terminal::Widgets::Widget;


#| Base for labeled input widgets that can only be clicked/pressed/selected
role Terminal::Widgets::Input::SimpleClickable
  is Terminal::Widgets::Widget
does Terminal::Widgets::Input
does Terminal::Widgets::Input::Labeled {
    # REQUIRED METHODS

    #| Perform click/press/select/activate action
    method click() { ... }

    #| Format the text in the widget's content area
    method content-text($label) { ... }


    #| Draw content area
    method draw-content() {
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;

        # XXXX: Temporary hack
        my $text   = $.terminal.locale.plain-text(self.content-text($.label));

        $.grid.set-span($x, $y, $text, self.current-color);
    }

    #| Handle minimal keyboard events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            ' '          => 'click',
            Ctrl-M       => 'click',  # CR/Enter
            KeypadEnter  => 'click',

            Ctrl-I       => 'focus-next',    # Tab
            ShiftTab     => 'focus-prev',    # Shift-Tab is weird and special
            ;

        with %keymap{$event.keyname} {
            # Allow navigation always, but only click/activate if enabled
            when 'click'      { self.click if $.enabled }
            when 'focus-next' { self.focus-next }
            when 'focus-prev' { self.focus-prev }
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
