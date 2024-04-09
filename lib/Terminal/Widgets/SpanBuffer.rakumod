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

        # Compute available viewer area; bail if empty or scrolled away
        my $layout = self.layout.computed;
        my $w      = 0 max $.w - $layout.width-correction;
        my $h      = 0 max $.h - $layout.height-correction;
        return unless $w && $h;

        # Grab a chunk of lines to render and the locale to render in
        my $chunk  = self.span-line-chunk($.y-scroll, $h);
        my $locale = self.terminal.locale;

        # Setup for rendering loop
        my $l = $layout.left-correction;
        my $t = $layout.top-correction;
        my $y = 0;

        # Render available lines
        while $y < $h {
            my $line = $chunk[$y] // last;
            self.draw-line-spans($l, $t + $y++, $w, $line,
                                 :$.x-scroll, :$locale);
        }
    }
}
