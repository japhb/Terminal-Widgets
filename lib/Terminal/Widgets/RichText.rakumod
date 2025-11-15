# ABSTRACT: A text widget that has clickable lines / a selected line.

use Text::MiscUtils::Layout;

use Terminal::Widgets::Events;
use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::Focusable;
use Terminal::Widgets::SpanWrappingAndHighlighting;

class Terminal::Widgets::RichText
 does Terminal::Widgets::SpanWrappingAndHighlighting
 does Terminal::Widgets::Focusable {
    has &.process-click;

    submethod TWEAK(:$wrap) {
        # The following is a workaround of https://github.com/rakudo/rakudo/issues/5599
        $!wrap = NoWrap;
        $!wrap = $wrap if $wrap;

        self.init-focusable;
    }

    #| Replace the contents of this RichText widget.
    method set-text(SpanContent $content) {
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
        self.toplevel.focus-on(self);

        my ($x, $y) = $event.relative-to(self);
        my $clicked-display-line = $!first-display-line + $y;
        my $line-index = @!dl-l[min($clicked-display-line, @!dl-l.end)];
        $!cursor-y = $line-index;
        my $rel-y = $y - @!l-dl[$line-index];
        $x = self!display-pos-to-line-pos(@!lines[$line-index], self.x-scroll + $x, $rel-y);
        $!cursor-x = min(self!chars-in-line(@!lines[$line-index]) - 1, $x);
        self.full-refresh;
        &!process-click($line-index, $x, 0) with &!process-click;
    }

    sub log($t) {
        "o".IO.spurt: $t ~ "\n", :append;
    }
}
