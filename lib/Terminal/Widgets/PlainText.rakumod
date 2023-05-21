# ABSTRACT: Plain text content

use Terminal::Widgets::Widget;


class Terminal::Widgets::PlainText is Terminal::Widgets::Widget {
    has Str:D $.text  = '';
    has Str:D $.color = '';

    method set-text(Str:D $!text)                   { self.refresh-all }
    method set-color(Str:D $!color)                 { self.refresh-all }
    method set-content(Str:D $!text, Str:D $!color) { self.refresh-all }

    method refresh-all() {
        self.clear-frame;
        self.draw-frame;
        self.composite(:print);
    }

    method draw-frame() {
        my @lines = $.text.lines;
        for @lines.kv -> $y, $line {
            $.grid.set-span(0, $y, $line, $.color);
        }
    }
}
