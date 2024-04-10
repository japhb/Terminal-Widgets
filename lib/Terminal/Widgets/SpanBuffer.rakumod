# ABSTRACT: A (possibly ragged) buffer of lines containing styled spans

use Terminal::Widgets::Widget;
use Terminal::Widgets::Scrollable;

#| Base role for any widget that is a scrollable buffer of (possibly
#| lazily-specified and/or ragged) lines containing styled spans
role Terminal::Widgets::SpanBuffer
  is Terminal::Widgets::Widget
does Terminal::Widgets::Scrollable {
    #  REQUIRED METHOD
    #| Grab a chunk of laid-out span lines for rendering, starting exactly at
    #| line $start.  May return greater or fewer lines than $wanted, and may
    #| even be empty, but if fewer that indicates there aren't any more lines
    #| available at the moment past the last returned line.  Content of each
    #| line should already be flattened into a simple list of spans.
    method span-line-chunk(UInt:D $start, UInt:D $wanted) { ... }

    #| Refresh widget display completely
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-frame;
        self.composite(:$print);
    }

    #| Render visible buffer lines
    method draw-frame() {
        # Draw framing first
        self.draw-framing;

        # Compute available content area; bail if empty
        my ($l, $t, $w, $h) = self.content-rect;
        return unless $w && $h;

        # Grab a chunk of lines to render and the locale to render in
        my $chunk  = self.span-line-chunk($.y-scroll, $h);
        my $locale = self.terminal.locale;

        # Render available lines
        my $y = 0;
        while $y < $h {
            my $line = $chunk[$y] // last;
            self.draw-line-spans($l, $t + $y++, $w, $line,
                                 :$.x-scroll, :$locale);
        }
    }
}
