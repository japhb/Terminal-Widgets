# ABSTRACT: Pausable event pump for parsed and decoded ANSI terminal events

use Terminal::LineEditor::RawTerminalInput;


#| A container for the unique ANSI terminal event pump for a given terminal
class Terminal::Widgets::Terminal
 does Terminal::LineEditor::RawTerminalIO
 does Terminal::LineEditor::RawTerminalUtils {

    #| Start the decoder reactor as soon as everything else is set up
    submethod TWEAK() {
        self.start-decoder;
    }
}
