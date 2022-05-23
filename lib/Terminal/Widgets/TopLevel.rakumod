# ABSTRACT: A top-level (full-screen) widget

use Terminal::Widgets::Terminal;
use Terminal::Widgets::Widget;


#| A top-level full-screen widget with modal access to its controlling terminal
class Terminal::Widgets::TopLevel
   is Terminal::Widgets::Widget {
    has Terminal::Widgets::Terminal:D $.terminal is required;
}
