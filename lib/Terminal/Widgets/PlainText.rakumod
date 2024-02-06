# ABSTRACT: Plain text content

use Terminal::Widgets::Widget;


#| A simple mono-colored plain text widget
class Terminal::Widgets::PlainText is Terminal::Widgets::Widget {
    has Str:D $.text  = '';
    has Str:D $.color = '';

    # Setters that also trigger display refresh
    method set-text(Str:D $!text)                   { self.full-refresh }
    method set-color(Str:D $!color)                 { self.full-refresh }
    method set-content(Str:D $!text, Str:D $!color) { self.full-refresh }

    #| Refresh widget display completely
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-frame;
        self.composite(:$print);
    }

    #| Render framing and text content to grid
    method draw-frame() {
        # XXXX: Drawing outside grid?
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;

        self.draw-framing;

        my @lines = $.text.lines;
        for @lines.kv -> $i, $line {
            $.grid.set-span($x, $y + $i, $line, $.color);
        }
    }
}
