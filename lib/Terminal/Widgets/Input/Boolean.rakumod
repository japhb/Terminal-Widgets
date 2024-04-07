# ABSTRACT: Base role for various boolean-valued input field widgets

use Terminal::Widgets::Input::SimpleClickable;


#| Base functionality for any boolean-valued input widget
role Terminal::Widgets::Input::Boolean
does Terminal::Widgets::Input::SimpleClickable {
    has Bool:D $.state = False;

    #| Boolean-specific gist flags
    method gist-flags() {
        |self.Terminal::Widgets::Input::gist-flags,
        'state:' ~ $!state
    }

    #| Set boolean state, then refresh
    method set-state(Bool:D $!state) { self.refresh-value;
                                       $_(self) with &.process-input; }

    #| Toggle current boolean state
    method toggle-state() { self.set-state(!$!state) }

    #| Convert .click to .toggle-state
    method click() { self.toggle-state }
}


#| Additional functionality for grouped boolean widgets, such as radio buttons
class Terminal::Widgets::Input::GroupedBoolean
 does Terminal::Widgets::Input::Boolean {
    has Str:D $.group is required;

    # Bump content-text requirement to subclasses
    method content-text($label) { ... }

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
