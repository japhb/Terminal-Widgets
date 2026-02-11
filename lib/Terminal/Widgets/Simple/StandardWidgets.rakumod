# ABSTRACT: Load all core widget types so they self-register

use Terminal::Widgets::Widget;
use Terminal::Widgets::PlainText;
use Terminal::Widgets::ScrollBar;

use Terminal::Widgets::Input::Menu;
use Terminal::Widgets::Input::Button;
use Terminal::Widgets::Input::Checkbox;
use Terminal::Widgets::Input::RadioButton;
use Terminal::Widgets::Input::ToggleButton;
use Terminal::Widgets::Input::Text;

use Terminal::Widgets::Viewer::Log;
use Terminal::Widgets::Viewer::Tree;
use Terminal::Widgets::Viewer::DirTree;
use Terminal::Widgets::Viewer::RichText;

use Terminal::Widgets::Viz::Sparkline;
use Terminal::Widgets::Viz::SmokeChart;
