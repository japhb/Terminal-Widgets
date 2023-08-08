# ABSTRACT: Core module to load all simplified classes/roles

use Terminal::Widgets::Form;
use Terminal::Widgets::Simple::App;
use Terminal::Widgets::Simple::TopLevel;


# Re-export classes under shorter names
constant Form     is export = Terminal::Widgets::Form;
constant App      is export = Terminal::Widgets::Simple::App;
constant TopLevel is export = Terminal::Widgets::Simple::TopLevel;
