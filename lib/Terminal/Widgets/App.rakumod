# ABSTRACT: Singleton terminal app object

use Terminal::Capabilities;

use Terminal::Widgets::TopLevel;
use Terminal::Widgets::Terminal;


#| A singleton TUI app object, managing Terminal and TopLevel objects
class Terminal::Widgets::App {
    has Instant $.bootup-instant is built(False);

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

        %caps<symbol-set> //= symbol-set(%caps<symbols> || 'Full');
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

    #| Convenience multi: construct a fresh App object, then continue with
    #| standard boot-to-screen method
    multi method boot-to-screen(::?CLASS:U: |c) { self.new.boot-to-screen(|c) }

    #| Boot up, create a default terminal and initialize it, create an initial
    #| toplevel attached to that terminal, switch to it, and start the terminal
    multi method boot-to-screen(::?CLASS:D: |c) {
        self.bootup;

        my $term = self.default-init(|c);
        $term.start
    }

    #| Perform startup processes that should happen before the first Terminal
    #| is initialized, when the launching VT is still showing the primary screen
    method bootup(|c) {
        # Make sure we see diagnostics immediately, even if $*ERR is redirected to a file
        $*ERR.out-buffer = False;

        # Provide hook for subclasses to perform boot-time initialization
        self.boot-init(|c);

        # Ready to switch to alternate screen, cleanup boot message if any
        if PROCESS::<$BOOTSTRAP_MESSAGE> -> $message {
            my $chars = $message.chars;
            print "\b" x $chars ~ ' ' x $chars ~ "\b" x $chars;
        }

        # Record end of bootup
        $!bootup-instant = now;
    }

    #| Boot-time (before alternate screen switch) initialization hook
    method boot-init() { }

    #| Create a default terminal and initial toplevel, associate them, and
    #| initialize the terminal
    method default-init(Str:D $toplevel-moniker,
                        Terminal::Widgets::TopLevel:U $class,
                        Str :$symbols = %*ENV<TW_SYMBOLS> // Str,
                        :$vt100-boxes = %*ENV<TW_VT100_BOXES>,
                        |c) {
        my $terminal = self.add-terminal(|(:symbols($_)     with $symbols),
                                         |(:vt100-boxes($_) with $vt100-boxes));
        my $toplevel = self.add-top-level($toplevel-moniker,
                                          :$class, :$terminal, |c);
        $terminal.initialize;
        $terminal.set-toplevel($toplevel);
        $terminal
    }
}
