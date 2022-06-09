# ABSTRACT: A top-level (full-screen) widget

use Terminal::Widgets::Terminal;
use Terminal::Widgets::Widget;
use Terminal::Widgets::Layout;


#| A top-level full-screen widget with modal access to its controlling terminal
role Terminal::Widgets::TopLevel
  is Terminal::Widgets::Widget
does Terminal::Widgets::Layout::WidgetBuilding {
    has Terminal::Widgets::Terminal:D $.terminal is required;
    has Str $.title;

    # XXXX: Allow terminal to be disconnected or switched?
    # XXXX: Does disconnect imply recursive destroy?
}
