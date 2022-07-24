# ABSTRACT: Pausable event pump for parsed and decoded ANSI terminal events

use Terminal::Print;
use Terminal::LineEditor::RawTerminalInput;

use Terminal::Widgets::Events;
use Terminal::Widgets::TopLevel;


#| A container for the unique ANSI terminal event pump for a given terminal
class Terminal::Widgets::Terminal
 does Terminal::LineEditor::RawTerminalIO
 does Terminal::LineEditor::RawTerminalUtils {
    has Terminal::Widgets::TopLevel $.current-toplevel;
    has Channel:D $.control         .= new;
    has Promise:D $.has-initialized .= new;
    has Promise:D $.has-started     .= new;
    has Promise:D $.has-shutdown    .= new;
    has           $!initialized-vow  = $!has-initialized.vow;
    has           $!started-vow      = $!has-started.vow;
    has           $!shutdown-vow     = $!has-shutdown.vow;
    has Bool:D    $.terminal-focused = True;
    has UInt:D    $.w = 0;
    has UInt:D    $.h = 0;
    has           $.app;

    # XXXX: Multiple T::P's in an app?
    has Terminal::Print:D $!terminal-print = PROCESS::<$TERMINAL> //= Terminal::Print.new;


    #| Initialize terminal size to value detected by Terminal::Print at startup
    submethod TWEAK() {
        $!w = $!terminal-print.columns;
        $!h = $!terminal-print.rows;
    }

    #| Initialize terminal screen and start per-terminal input decoder in background
    method initialize {
        $!terminal-print.initialize-screen;
        self.start-decoder;
        $!initialized-vow.keep(True);
    }

    #| Enter raw input mode, enable mouse events, and start per-terminal
    #| event reactor ready to pass events to toplevels
    method start {
        self.enter-raw-mode;
        self.set-mouse-event-mode(MouseNormalEvents);

        react {
            # Handle events from the control channel
            whenever $.control {
                # Handle window size change synchronously, since we have to
                # query the VT emulator for the new size info
                when 'refresh-terminal-size' { await self.refresh-terminal-size }

                # Exit terminal reactor when requested
                when 'done' { done }

                # Something is coded wrong if the control channel hits the default
                default { !!! "Unknown control channel event: '$_'" }
            }

            # Send the window resize request to the control channel
            # and let the signal handler finish
            whenever signal(SIGWINCH) {
                $.control.send: 'refresh-terminal-size';
            }

            # Keyboard and mouse events
            whenever $.decoded {
                # End terminal event processing if input ended
                done unless .defined;

                # Check for events changing focus of entire terminal window
                if $_ ~~ Pair && .key ~~ SpecialKey {
                    if    .key == FocusIn  { $!terminal-focused = True  }
                    elsif .key == FocusOut { $!terminal-focused = False }
                }

                # Wrap low-level event into higher-level wrapper
                my $event = $_ ~~ MouseTrackingEvent
                            ?? Terminal::Widgets::Events::MouseEvent.new(mouse => $_)
                            !! Terminal::Widgets::Events::KeyboardEvent.new(key => $_);
                # note $event;

                # Send the high-level event to the current toplevel for processing
                .process-event($event) with $.current-toplevel;
            }

            # Let watchers know the terminal reactor has started
            $!started-vow.keep(True);
        }

        self!shutdown;
    }

    #| Refresh the terminal size (at start or after SIGWINCH/SIGCONT),
    #| resizing/redrawing the current toplevel widget if any; returns a
    #| Promise that will be kept when the resize completes.
    method refresh-terminal-size() {
        # XXXX: Cannot use locking I/O methods on $.input here, such as .t or
        #       .native-descriptor; they will deadlock inside MoarVM with the
        #       pending $.input.read in RawTerminalInput.start-parser.
        die "Cannot detect terminal size on closed or non-TTY I/O handles"
            unless $.input.opened && $.output.t;

        self.detect-terminal-size.then: {
            my $size = .result;
            die "Unable to detect terminal size!" unless $size.elems == 2;

            if $!h != $size[0] || $!w != $size[1] {
                ($!h, $!w) = @$size;
                self.resize-toplevel;
            }
        }
    }

    #| Resize current toplevel to match current terminal size (either because
    #| terminal has resized or toplevel has been changed)
    method resize-toplevel() {
        with $.current-toplevel {
            my $is-current-grid = .grid === $!terminal-print.current-grid;

            # note "Updating toplevel geometry to $!w x $!h"; $*ERR.flush;
            my $old-grid = .grid;
            .update-geometry(:$!w, :$!h);
            my $new-grid = .grid;
            unless $is-current-grid && $old-grid === $new-grid {
                my $name = ~.WHICH;
                # XXXX: Old grid leaks in Terminal::Print
                # XXXX: Need a .replace-grid for T::P as well?
                $!terminal-print.add-grid($name, :$new-grid);
                $!terminal-print.switch-grid($name);
            }

            # note "Rebuilding layout"; $*ERR.flush;
            .build-layout;
            # note .layout.gist;
            # note "Focusing on toplevel"; $*ERR.flush;
            .gain-focus(:!redraw);
            # note "Redrawing toplevel"; $*ERR.flush;
            .redraw-all;
            # note "Recompositing toplevel"; $*ERR.flush;
            .composite;
            # note "Toplevel resize complete.\n"; $*ERR.flush;
        }
    }

    #| Set/change toplevel, resizing if needed
    method set-toplevel($new-toplevel) {
        # XXXX: Tell previous toplevel to disconnect from terminal?

        if $new-toplevel -> $!current-toplevel {
            self.set-window-title($_) with $!current-toplevel.title;
            self.resize-toplevel if $!w && $!h;
        }
    }

    #| Set terminal emulator window title
    method set-window-title(Str:D $title) {
        $.output.print("\e]2;$title\e\\");
    }

    #| Exit from various per-terminal reactors and allow shutdown to proceed
    method quit() {
        if $.has-started {
            self.set-done;            # Stop input parser reactor
            $.control.send: 'done';   # Stop main event reactor
        }
        else {
            self!shutdown;
        }
    }

    #| Gracefully shutdown this terminal; users should use .quit() instead
    #| so that the per-terminal reactors are exited *first*
    method !shutdown() {
        # Forget current toplevel window
        self.set-toplevel(Nil);

        # Clean up terminal raw I/O state
        self.set-mouse-event-mode(MouseNoEvents) if $.output.opened;
        self.leave-raw-mode(:!nl)                if  $.input.opened;

        # Shutdown Terminal::Print instance (returning to normal screen buffer)
        $!terminal-print.shutdown-screen;

        # Close non-standard handles
        $.input.close  if  $.input.opened &&  $.input.native-descriptor > 2;
        $.output.close if $.output.opened && $.output.native-descriptor > 2;

        # Let watchers know the terminal has fully shut down
        $!shutdown-vow.keep(True);
    }
}
