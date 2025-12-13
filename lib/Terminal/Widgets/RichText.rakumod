# ABSTRACT: A text widget that has clickable lines / a selected line.

use Terminal::Widgets::Layout;
use Terminal::Widgets::Events;
use Terminal::Widgets::Focusable;
use Terminal::Widgets::SpanWrappingAndHighlighting;


#| Layout node for a rich text viewer widget
class Terminal::Widgets::Layout::RichText
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'rich-text' }
}


#| A rich text viewer widget
class Terminal::Widgets::RichText
 does Terminal::Widgets::SpanWrappingAndHighlighting
 does Terminal::Widgets::Focusable {
    has &.process-click;

    method layout-class() { Terminal::Widgets::Layout::RichText }

    submethod TWEAK(:$wrap) {
        # The following is a workaround of https://github.com/rakudo/rakudo/issues/5599
        $!wrap = NoWrap;
        $!wrap = $wrap if $wrap;
    }

    method set-text($content) {
        self!set-text: $content;
    }

    method splice-lines($from, $count, $replacement) {
        self!splice-lines: $from, $count, $replacement;
    }

    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorDown  => 'select-next-line',
            CursorUp    => 'select-prev-line',
            CursorLeft  => 'select-prev-char',
            CursorRight => 'select-next-char',
            Ctrl-I      => 'focus-next',    # Tab
            ShiftTab    => 'focus-prev',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'select-next-line' { self!select-line($!cursor-y + 1) }
            when 'select-prev-line' { self!select-line($!cursor-y - 1) }
            when 'select-next-char' { self!next-char }
            when 'select-prev-char' { self!prev-char }
            when 'focus-next'       { self.focus-next }
            when 'focus-prev'       { self.focus-prev }
        }
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Take focus even if clicked on framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled and within content area, move cursor and process click
        if $.enabled {
            my ($x, $y, $w, $h) = $event.relative-to-content-area(self);

            if 0 <= $x < $w && 0 <= $y < $h {
                my $clicked-display-line = $!first-display-line + $y;
                my $line-index = @!dl-l[$clicked-display-line min @!dl-l.end];
                $!cursor-y = $line-index;
                my $rel-y = $y - @!l-dl[$line-index];

                $x = self!display-pos-to-line-pos(@!lines[$line-index],
                                                  self.x-scroll + $x, $rel-y);
                $!cursor-x = $x min self!chars-in-line(@!lines[$line-index]) - 1;
                $_($line-index, $x, 0) with &!process-click;
            }
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }
}


# Register RichText as a buildable widget type
Terminal::Widgets::RichText.register;
