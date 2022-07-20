# ABSTRACT: Singleton terminal app object

use Terminal::Widgets::TopLevel;
use Terminal::Widgets::Terminal;


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

        %!terminal{$tty.path} = Terminal::Widgets::Terminal.new(:$input, :$output,
                                                                :app(self));
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
                         Terminal::Widgets::TopLevel:U :$class,
                         Terminal::Widgets::Terminal:D :$terminal, |c) {
        my $w = $terminal.w;
        my $h = $terminal.h;
        %!top-level{$moniker} = $class.new(:$terminal, :$w, :$h, :x(0), :y(0), |c);
    }

    # XXXX: Need to be able to dispose of toplevels as well

    #| Shutdown and remove a terminal by terminal moniker
    multi method remove-terminal(Str:D $moniker) {
        my $terminal = %!terminal{$moniker}:delete
             or die "Terminal moniker '$moniker' not found";

        # XXXX: Disconnect/destroy matching toplevels?

        $terminal.quit;
    }

    #| Shutdown and remove a terminal by terminal object
    multi method remove-terminal(Terminal::Widgets::Terminal:D $terminal) {
        my $moniker = %!terminal.pairs.first(*.value === $terminal).key
            or die "Terminal object not known to app";
        self.remove-terminal($moniker);
    }

    #| Create a default terminal and initial toplevel, associate them, and
    #| initialize the terminal
    method default-init(Str:D $toplevel-moniker,
                        Terminal::Widgets::TopLevel:U $class, |c) {
        my $terminal = self.add-terminal;
        my $toplevel = self.add-top-level($toplevel-moniker,
                                          :$class, :$terminal, |c);
        $terminal.initialize;
        $terminal.set-toplevel($toplevel);
        $terminal
    }
}
