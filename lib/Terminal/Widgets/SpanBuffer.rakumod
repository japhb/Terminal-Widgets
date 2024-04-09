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

    #| Render spans on a single line, optimizing for monospace spans
    method draw-line-spans(UInt:D $line-x is copy, UInt:D $line-y, UInt:D $w,
                           @line, UInt:D :$x-scroll = 0,
                           :$locale = self.terminal.locale) {
        my $span-x = 0;
        for @line {
            my $next = $span-x + .width;
            if .width == .text.chars {
                if $next <= $x-scroll + $w && $x-scroll <= $span-x {
                    # Span fully visible and monospace; render entire span.
                    # This is the fastest span path.
                    $.grid.set-span($line-x, $line-y, .text, .color);
                    $line-x += .width;
                }
                elsif $x-scroll < $next {
                    # Span partially visible and monospace; render
                    # visible substring.  This is the medium speed path.
                    my $start   = 0 max $x-scroll - $span-x;
                    my $max-len = 0 max $w - (0 max $span-x - $x-scroll);
                    my $text    = substr(.text, $start, $max-len);

                    $.grid.set-span($line-x, $line-y, $text, .color);
                    $line-x += $text.chars;
                }
            }
            elsif $x-scroll < $next {
                # Span duospaced and cut off by x-scroll or width; need to
                # render cell-by-cell.  This is a potentially slow path!

                # XXXX: Run this for loop with grid lock held and update
                #       cells manually to avoid repeated call overhead?

                # XXXX: Currently leaves untouched split character cells;
                #       should this overwrite with ' ' instead?

                for .text.comb {
                    my $width  = $locale.width($_);
                    my $c-next = $line-x + $width;
                    last if $c-next > $w;

                    if $x-scroll <= $span-x {
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
    }
}
