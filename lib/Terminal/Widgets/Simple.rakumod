# ABSTRACT: Core module to load all simplified classes/roles

use Terminal::Widgets::App;
use Terminal::Widgets::Simple::TopLevel;


# Re-export classes under shorter names
constant TopLevel is export = Terminal::Widgets::Simple::TopLevel;


#| Instantiate UI class as first screen in a TUI app (implicitly sets up terminal)
sub first-screen(|c) is export {
    my $app  = Terminal::Widgets::App.new;
    my $term = $app.default-init(|c);
}
