# ABSTRACT: Singleton terminal app object

use Terminal::Widgets::Terminal;
use Terminal::Widgets::TopLevel;


#| A singleton TUI app object, managing Terminal and TopLevel objects
class Terminal::Widgets::App {
    has %!terminal;
    has %!top-level;

    #| Create a new Terminal container for a given named tty, add the new
    #| container to internal data structures, and return it.
    multi method add-terminal(IO::Path:D   :$tty!,
                              IO::Handle:D :$input  = $tty.open(:r),
                              IO::Handle:D :$output = $tty.open(:a)) {
        die "Terminal input and output are not both connected to a valid tty"
            unless $input.t && $output.t;

        %!terminal{$tty.path} = Terminal::Widgets::Terminal.new(:$input, :$output)
    }

    #| add-terminal by IO::Path tty object
    multi method add-terminal(IO::Path:D $tty) {
        self.add-terminal(:$tty);
    }

    #| add-terminal by Str tty-name, defaulting to '/dev/tty' (controlling terminal)
    multi method add-terminal(Str:D $tty-name = '/dev/tty') {
        self.add-terminal($tty-name.IO);
    }

    #| Create a new top-level widget of a given class, add it to the known
    #| top-level widgets, and return it.
    method add-top-level(Str:D $moniker,
                         Terminal::Widgets::TopLevel:U :$class) {
        %!top-level{$moniker} = $class.new;
    }

    # XXXX: Need to be able to dispose of terminals and toplevels as well

    # XXXX: Testing the API
    method default-start() {
        my $terminal = self.add-terminal;
        my $main     = self.add-top-level('main');
        $terminal.set-toplevel($main);
    }
}
