# ABSTRACT: Simplified terminal app class

use Terminal::Widgets::App;
use Terminal::Widgets::Progress::Tracker;


#| Simplified singleton TUI app object, with various convenience methods
class Terminal::Widgets::Simple::App is Terminal::Widgets::App {
    has Instant $.bootup-instant               is built(False);
    has Instant $.terminal-added-instant       is built(False);
    has Instant $.terminal-initialized-instant is built(False);


    ### Stubbed hooks for subclasses

    #| Boot-time (before alternate screen switch) initialization hook
    method boot-init() { }

    #| Make a progress tracker for a loading screen (stub is invisible)
    method make-progress-tracker(Terminal::Widgets::Terminal:D $terminal) {
        Terminal::Widgets::Progress::Tracker.new
    }

    #| Start work for loading screen, returning Promises for each major task,
    #| and updating the progress $tracker as work gets done
    method loading-promises(Terminal::Widgets::Progress::Tracker:D $tracker) {
        Empty
    }


    ### boot-to-X convenience methods

    #| Boot up, create a default terminal and initialize it (thus switching to
    #| the alternate screen), stop there and return the Terminal object
    method boot-to-terminal(::?CLASS:D: |c) {
        self.bootup;

        my $terminal = self.add-terminal(|c);
        $!terminal-added-instant = now;
        $terminal.initialize;
        $!terminal-initialized-instant = now;

        $terminal
    }

    #| Start with boot-to-terminal, then display a loading screen and optionally
    #| a Progress::Tracker, start the loading-promises, then await them and set
    #| the tracker's progress to complete, returning the Terminal object
    method boot-to-loading-screen(::?CLASS:D: |c) {
        my $terminal = self.boot-to-terminal(|c);

        self.loading-screen($terminal);
        $terminal
    }

    #| Boot up, create a default terminal and initialize it, create an initial
    #| toplevel attached to that terminal, switch to it, and start the terminal
    method boot-to-screen(::?CLASS:D: |c) {
        self.bootup;

        my $term = self.default-init(|c);
        $term.start
    }


    ### Core implementation

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
            print chr(8) x $chars ~ ' ' x $chars ~ chr(8) x $chars;  # chr(8) = Backspace
        }

        # Record end of bootup
        $!bootup-instant = now;
    }

    #| Display a loading screen on a raw (but initialized) Terminal
    multi method loading-screen(Terminal::Widgets::Terminal:D $terminal, |c) {
        # Make a progress tracker for the user, then proceed with loading
        # screen as usual
        self.loading-screen(self.make-progress-tracker($terminal), |c)
    }

    #| Display a loading screen using a pre-defined progress Tracker
    multi method loading-screen(Terminal::Widgets::Progress::Tracker:D $tracker, |c) {
        # Spawn loading promises (the actual loading work)
        my @loading-promises = self.loading-promises($tracker, |c);

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
        $!terminal-added-instant = now;

        my $toplevel = self.add-top-level($toplevel-moniker,
                                          :$class, :$terminal, |c);
        $terminal.initialize;
        $!terminal-initialized-instant = now;

        $terminal.set-toplevel($toplevel);
        $terminal
    }
}
