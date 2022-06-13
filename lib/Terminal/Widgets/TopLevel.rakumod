# ABSTRACT: A top-level (full-screen) widget

use Terminal::Widgets::Widget;
use Terminal::Widgets::Events;
use Terminal::Widgets::Layout;


#| A top-level full-screen widget with modal access to its controlling terminal
role Terminal::Widgets::TopLevel
  is Terminal::Widgets::Widget
does Terminal::Widgets::Layout::WidgetBuilding {
    has     $.terminal is required;
    has Str $.title;

    #| Check if the Terminal believes this is its current TopLevel
    method is-current-toplevel(--> Bool:D) {
        self === $.terminal.current-toplevel
    }

    #| Send an event requesting that a target widget takes focus
    method focus-on(Terminal::Widgets::Widget:D $target) {
        self.process-event(Terminal::Widgets::Events::TakeFocus.new(:$target));
    }

    # XXXX: Allow terminal to be disconnected or switched?
    # XXXX: Does disconnect imply recursive destroy?
}
