# ABSTRACT: General viewer for rich text content

use Text::MiscUtils::Layout;

use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::Layout;
use Terminal::Widgets::WrappableBuffer;


#| Layout node for a rich text viewer widget
class Terminal::Widgets::Layout::RichTextViewer
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'rich-text-viewer' }
}


#| Available text highlight modes, from narrowest to widest
enum Terminal::Widgets::HighlightMode is export
    < NoHighlight GraphemeHighlight RenderSpanHighlight StringSpanHighlight
      SoftLineHighlight HardLineHighlight LineGroupHighlight >;

my constant %span-prop-map =
    (NoHighlight)         => '',
    (GraphemeHighlight)   => 'render-span',
    (RenderSpanHighlight) => 'render-span',
    (StringSpanHighlight) => 'string-span',
    (SoftLineHighlight)   => 'render-span',
    (HardLineHighlight)   => 'lg-hard-line',
    (LineGroupHighlight)  => 'line-group-id',
    ;


#| General viewer for rich text content
class Terminal::Widgets::Viewer::RichText
 does Terminal::Widgets::WrappableBuffer {
    has Terminal::Widgets::HighlightMode:D $.highlight-mode is rw = NoHighlight;
    has Terminal::Widgets::HighlightMode:D $.cursor-mode    is rw = NoHighlight;

    method layout-class() { Terminal::Widgets::Layout::RichTextViewer }

    #| Post-process the lines in a (partially-?) visible LineGroup before
    #| display; in this case, highlight any selected line/span
    method post-process-line-group($lg-id, $first-line, $start-line, $last-line, @lines) {
        my $should-process = $!highlight-mode || $!cursor-mode;
        my $selected-id    = %!selected-span-info<line-group-id> // 0;

        if $should-process && $lg-id == $selected-id {
            # Prepare to colorize cursor and highlight region
            my $colorset  = $.terminal.colorset;
            my $c-color   = $colorset.cursor;
            my $h-color   = $colorset.highlight;
            my $c-target  = %!selected-span-info{%span-prop-map{$!cursor-mode}};
            my $h-target  = %!selected-span-info{%span-prop-map{$!highlight-mode}};

            # Determine visible bounds
            my $pos       = 0 max $start-line - $first-line;
            my $end       = @lines.elems;

            # Move lines before start-line over unchanged
            my @processed = @lines[^$pos];

            # Process remaining lines until past $last-line
            while $pos < $end {
                my $cur-line = $first-line + $pos;
                last if $cur-line > $last-line;

                # Active line (array of RenderSpans), before processing
                my $line = @lines[$pos];

                # Helper sub: Highlight with a given color based on
                #             highlighting mode and current target
                my sub highlight($mode, $color, $target) {
                    return unless $mode && $color;

                    # Helper sub: Highlight spans for which predicate returns True
                    my sub hl-spans(&should-highlight) {
                        # Process spans as needed
                        my @line = $line.map: {
                            should-highlight($_)
                            ?? .clone(color => color-merge(.color, $color))
                            !! $_
                        }

                        # Replace plain line with processed version
                        $line = @line;
                    }

                    given $mode {
                        when LineGroupHighlight {
                            hl-spans({True});
                        }
                        when HardLineHighlight {
                            hl-spans({ (my $ss = $^span.string-span) &&
                                       (my $attrs = $ss.attributes) &&
                                       $attrs<lg-hard-line> == $target });
                        }
                        when SoftLineHighlight {
                            hl-spans({True}) if $line.first(* === $target);
                        }
                        when StringSpanHighlight {
                            hl-spans(*.string-span === $target);
                        }
                        when RenderSpanHighlight {
                            hl-spans(* === $target);
                        }
                        when GraphemeHighlight {
                            # This could require span-splitting, so use a
                            # bespoke highlighting loop for this case

                            my $start-x = 0;
                            my @line;

                            for @$line -> $span {
                                my $width = $span.width;
                                my $next  = $start-x + $width;

                                # If within selected span ...
                                if $span === $target && $.cursor-x < $next {
                                    # Collect info for creating span pieces
                                    my $text   = $span.text;
                                    my $chars  = $text.chars;
                                    my $color  = $span.color;
                                    my $merged = color-merge($color, $h-color);

                                    if $chars <= 1 {
                                        # If at most one character in span,
                                        # just highlight the whole span.
                                        @line.push: $span.clone(color => $merged);
                                    }
                                    else {
                                        # Otherwise, split span into before,
                                        # highlit, after.  Don't bother with
                                        # wrapping logic, that's already
                                        # happened previously.

                                        my $loc = $.cursor-x - $start-x;
                                        my $is-mono = $width == $chars
                                                   && is-monospace-core($text, 0);

                                        # Correct $loc if duospace span
                                        unless $is-mono {
                                            my $x = 0;
                                            my $l = 0;
                                            while $x < $loc && $l < $chars {
                                                my $c = substr($text, $l, 1);
                                                $x += duospace-width-core($c, 0);
                                                $l++;
                                            }
                                            $l-- if $x > $loc;
                                            $loc = $l;
                                        }

                                        # Split into three pieces
                                        my $before  = substr($text, 0, $loc);
                                        my $highlit = substr($text, $loc, 1);
                                        my $after   = substr($text, $loc + 1);

                                        # Create new spans for each piece
                                        my $string-span = $span.string-span;
                                        if $before {
                                            @line.push: $span.new(:$string-span,
                                                                  :$color,
                                                                  text => $before);
                                        }
                                        if $highlit {
                                            @line.push: $span.new(:$string-span,
                                                                  color => $merged,
                                                                  text => $highlit);
                                        }
                                        if $after {
                                            @line.push: $span.new(:$string-span,
                                                                  :$color,
                                                                  text => $after);
                                        }
                                    }
                                }
                                else {
                                    @line.push($span);
                                }

                                $start-x = $next;
                            }

                            # Replace plain line with processed version
                            $line = @line;
                        }
                        default { !!! "Unknown buffer highlight mode $_" }
                    }
                }

                # Highlight first if needed before marking cursor
                highlight($!highlight-mode, $h-color, $h-target);
                highlight($!cursor-mode,    $c-color, $c-target);

                # Push processed line and go to next
                @processed.push($line);
                $pos++;
            }

            # Return the processed lines
            @processed
        }
        else {
            # Default behavior: Just return the lines unchanged
            @lines
        }
    }
}


# Register Viewer::RichText as a buildable widget type
Terminal::Widgets::Viewer::RichText.register;
