# ABSTRACT: Pausable event pump for parsed and decoded ANSI terminal events

use Terminal::LineEditor::RawTerminalInput;

use Terminal::Widgets::Widget;


#| A container for the unique ANSI terminal event pump for a given terminal
class Terminal::Widgets::Terminal
 does Terminal::LineEditor::RawTerminalIO
 does Terminal::LineEditor::RawTerminalUtils {
    has Terminal::Widgets::Widget $.current-toplevel is rw;
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
        self.detect-terminal-size.then: {
            my $size = .result;
            die "Unable to detect terminal size!" unless $size.elems == 2;

            if $!h != $size[0] || $!w != $size[1] {
                ($!h, $!w) = @$size;
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
        }
    }
}
