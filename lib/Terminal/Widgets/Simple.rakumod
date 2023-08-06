# ABSTRACT: Core module to load all simplified classes/roles

use Terminal::Widgets::App;
use Terminal::Widgets::Form;
use Terminal::Widgets::Simple::TopLevel;


# Re-export classes under shorter names
constant App      is export = Terminal::Widgets::App;
constant Form     is export = Terminal::Widgets::Form;
constant TopLevel is export = Terminal::Widgets::Simple::TopLevel;
