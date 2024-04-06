# ABSTRACT: Base role for various boolean-valued input field widgets

use Terminal::Widgets::I18N::Translation;
use Terminal::Widgets::Events;
use Terminal::Widgets::Input;


#| Base functionality for any boolean-valued input widget
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
        my $label  = $.label ~~ TranslatableString
                     ?? ~$.terminal.locale.translate($.label) !! ~$.label;

        self.draw-framing;
        $.grid.set-span($x, $y, self.content-text($label), self.current-color);
    }

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


#| Additional functionality for grouped boolean widgets, such as radio buttons
class Terminal::Widgets::Input::GroupedBoolean
 does Terminal::Widgets::Input::Boolean {
    has Str:D $.group is required;

    #| Make sure grouped boolean widget is added to group within toplevel
    submethod TWEAK() {
        self.Terminal::Widgets::Input::TWEAK;
        self.toplevel.add-to-group(self, $!group);
    }

    #| All grouped boolean widgets in this widget's group
    method group-members() {
        self.toplevel.group-members($!group)
    }

    #| Selected member of this widget's group
    method selected-member() {
        self.group-members.first(*.state)
    }

    #| If setting this widget, unset remainder in group
    method set-state(Bool:D $state) {
        self.Terminal::Widgets::Input::Boolean::set-state($state);
        if $state {
            .set-state(False) for self.group-members.grep(* !=== self);
        }
    }
}
