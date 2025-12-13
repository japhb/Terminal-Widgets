# ABSTRACT: Core module to load all widget types and simplified classes/roles

# Load all core widget types so they self-register
use Terminal::Widgets::Widget;
use Terminal::Widgets::PlainText;
use Terminal::Widgets::RichText;
use Terminal::Widgets::TreeView;

use Terminal::Widgets::Input::Menu;
use Terminal::Widgets::Input::Button;
use Terminal::Widgets::Input::Checkbox;
use Terminal::Widgets::Input::RadioButton;
use Terminal::Widgets::Input::ToggleButton;
use Terminal::Widgets::Input::Text;

use Terminal::Widgets::Viewer::Log;
use Terminal::Widgets::Viewer::Tree;
use Terminal::Widgets::Viewer::DirTree;

use Terminal::Widgets::Viz::SmokeChart;


# Load classes to be re-exported
use Terminal::Widgets::Form;
use Terminal::Widgets::Simple::App;
use Terminal::Widgets::Simple::TopLevel;


# Re-export classes under shorter names
constant Form     is export = Terminal::Widgets::Form;
constant App      is export = Terminal::Widgets::Simple::App;
constant TopLevel is export = Terminal::Widgets::Simple::TopLevel;
