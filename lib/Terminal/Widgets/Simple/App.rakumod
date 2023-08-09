# ABSTRACT: Simplified terminal app class

use Terminal::Widgets::App;
use Terminal::Widgets::Progress::Tracker;


#| Simplified singleton TUI app object, with various convenience methods
class Terminal::Widgets::Simple::App is Terminal::Widgets::App {
    has Instant $.bootup-instant is built(False);


    ### Stubbed hooks for subclasses

    #| Boot-time (before alternate screen switch) initialization hook
    method boot-init() { }

    #| Make a progress tracker for a loading screen (stub is invisible)
    method make-progress-tracker() {
        Terminal::Widgets::Progress::Tracker.new
    }

    #| Start work for loading screen, returning Promises for each major task,
    #| and updating the progress $tracker as work gets done
    method loading-promises(Terminal::Widgets::Progress::Tracker:D $tracker) {
        Empty
    }


    ### Core implementation

    #| Boot up, create a default terminal and initialize it, create an initial
    #| toplevel attached to that terminal, switch to it, and start the terminal
    method boot-to-screen(::?CLASS:D: |c) {
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

    method loading-screen() {
        # Make a progress tracker for the user
        my Terminal::Widgets::Progress::Tracker:D $tracker = self.make-progress-tracker;

        # Spawn loading promises (the actual loading work)
        my @loading-promises = self.loading-promises($tracker);

        # Ensure all work is done, and show progress complete
        await @loading-promises;
        $tracker.set-complete;
    }

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
