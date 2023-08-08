# ABSTRACT: Singleton terminal app object

use Terminal::Capabilities;

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
                              IO::Handle:D :$output = $tty.open(:a),
                              *%caps) {
        die "Terminal input and output are not both connected to a valid tty"
            unless $input.t && $output.t;

        %caps<symbol-set> //= symbol-set(%caps<symbols> || %*ENV<TW_SYMBOLS> || 'Full');

        # This contortion avoids an error trying to assign to a type object
        without %caps<vt100-boxes> {
            %caps<vt100-boxes>:delete;
            %caps<vt100-boxes> = ?+$_ with %*ENV<TW_VT100_BOXES>;
        }

        my $caps = Terminal::Capabilities.new(|%caps);
        %!terminal{$tty.path} = Terminal::Widgets::Terminal.new(:$input, :$output,
                                                                :$caps, :app(self));
    }

    #| add-terminal by IO::Path tty object
    multi method add-terminal(IO::Path:D $tty, *%caps) {
        self.add-terminal(:$tty, |%caps);
    }

    #| add-terminal by Str tty-name, defaulting to '/dev/tty' (controlling terminal)
    multi method add-terminal(Str:D $tty-name = '/dev/tty', *%caps) {
        self.add-terminal($tty-name.IO, |%caps);
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
}
