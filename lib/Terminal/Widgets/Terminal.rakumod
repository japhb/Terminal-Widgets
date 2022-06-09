# ABSTRACT: Pausable event pump for parsed and decoded ANSI terminal events

use Terminal::LineEditor::RawTerminalInput;

use Terminal::Widgets::Widget;


#| A container for the unique ANSI terminal event pump for a given terminal
class Terminal::Widgets::Terminal
 does Terminal::LineEditor::RawTerminalIO
 does Terminal::LineEditor::RawTerminalUtils {
    has Terminal::Widgets::Widget $.current-toplevel;
    has UInt:D $.w = 0;
    has UInt:D $.h = 0;

    #| Start the decoder reactor as soon as everything else is set up
    submethod TWEAK() {
        self.start-decoder;
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
            # note "Updating toplevel geometry to $size"; $*ERR.flush;
            .update-geometry(:$!w, :$!h);
            # note "Rebuilding layout"; $*ERR.flush;
            .build-layout;
            # note .layout.gist;
            # note "Recomposing toplevel"; $*ERR.flush;
            .composite;
            # note "Toplevel resize complete.\n"; $*ERR.flush;
        }
    }

    #| Set/change toplevel, resizing if needed
    method set-toplevel($new-toplevel) {
        # XXXX: Tell previous toplevel to disconnect from terminal?

        if $new-toplevel -> $!current-toplevel {
            self.resize-toplevel if $!w && $!h;
        }
    }

    #| Shutdown this terminal and close handles (if not standard handles)
    method shutdown() {
        # Forget current toplevel window
        self.set-toplevel(Nil);

        # Clean up terminal raw I/O state
        self.set-mouse-event-mode(MouseNoEvents) if $.output.opened;
        self.leave-raw-mode(:!nl)                if  $.input.opened;

        # XXXX: T::P shutdown?

        # Close non-standard handles
        $.input.close  if  $.input.opened &&  $.input.native-descriptor > 2;
        $.output.close if $.output.opened && $.output.native-descriptor > 2;
    }
}
