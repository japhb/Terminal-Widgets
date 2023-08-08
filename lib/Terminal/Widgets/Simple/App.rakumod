# ABSTRACT: Simplified terminal app class

use Terminal::Widgets::App;


class Terminal::Widgets::Simple::App is Terminal::Widgets::App {
    has Instant $.bootup-instant is built(False);

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
                        Str :$symbols, :$vt100-boxes, |c) {
        my $terminal = self.add-terminal(|(:symbols($_)     with $symbols),
                                         |(:vt100-boxes($_) with $vt100-boxes));
        my $toplevel = self.add-top-level($toplevel-moniker,
                                          :$class, :$terminal, |c);
        $terminal.initialize;
        $terminal.set-toplevel($toplevel);
        $terminal
    }
}
