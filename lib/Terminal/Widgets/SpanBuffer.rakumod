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

        # Grab a chunk of lines to render
        my $chunk = self.span-line-chunk($.y-scroll, $h);

        # Setup for rendering loops
        my $l      = $layout.left-correction;
        my $t      = $layout.top-correction;
        my $y      = 0;
        my $xs     = $.x-scroll;
        my $locale = self.terminal.locale;

        # Render available lines
        while $y < $h {
            my $line   = $chunk[$y] // last;
            my $line-y = $t + $y;
            my $line-x = $l;
            my $span-x = 0;

            # Render spans on this line, optimizing for monospace spans
            for @$line {
                my $next = $span-x + .width;
                if .width == .text.chars {
                    if $next <= $xs + $w && $xs <= $span-x {
                        # Span fully visible and monospace; render entire span.
                        # This is the fastest span path.
                        $.grid.set-span($line-x, $line-y, .text, .color);
                        $line-x += .width;
                    }
                    elsif $xs < $next {
                        # Span partially visible and monospace; render
                        # visible substring.  This is the medium speed path.
                        my $start   = 0 max $xs - $span-x;
                        my $max-len = 0 max $w - (0 max $span-x - $xs);
                        my $text    = substr(.text, $start, $max-len);

                        $.grid.set-span($line-x, $line-y, $text, .color);
                        $line-x += $text.chars;
                    }
                }
                elsif $xs < $next {
                    # Span duospaced and cut off by x-scroll or width; need to
                    # render cell-by-cell.  This is a potentially slow path!

                    # XXXX: Currently leaves untouched split character cells;
                    #       should this overwrite with ' ' instead?

                    for .text.comb {
                        my $width  = $locale.width($_);
                        my $c-next = $line-x + $width;
                        last if $c-next > $w;

                        if $xs <= $span-x {
                            # Update optionally-colored first cell;
                            # empty second cell if character was wide.
                            my $cell = .color ?? $.grid.cell($_, .color) !! $_;
                            $.grid.change-cell($line-x,     $line-y, $cell);
                            $.grid.change-cell($line-x + 1, $line-y, '')
                                if $width > 1;
                        }

                        $span-x += $width;
                        $line-x  = $c-next;
                    }
                }

                last if ($span-x = $next) >= $w;
            }

            ++$y;
        }
    }
}
