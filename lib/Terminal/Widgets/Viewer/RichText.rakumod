# ABSTRACT: General viewer for rich text content

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

#| Available cursor marking/handling modes, from narrowest to widest
enum Terminal::Widgets::CursorMode is export
    < NoCursor GraphemeCursor RenderSpanCursor StringSpanCursor
      SoftLineCursor HardLineCursor LineGroupCursor >;

my constant %span-prop-map =
    (NoHighlight)         => '',
    (GraphemeHighlight)   => '',  # NYI
    (RenderSpanHighlight) => 'render-span',
    (StringSpanHighlight) => 'string-span',
    (SoftLineHighlight)   => 'render-span',
    (HardLineHighlight)   => 'lg-hard-line',
    (LineGroupHighlight)  => 'line-group-id',

    (NoCursor)            => '',
    (GraphemeCursor)      => '',  # NYI
    (RenderSpanCursor)    => 'render-span',
    (StringSpanCursor)    => 'string-span',
    (SoftLineCursor)      => 'render-span',
    (HardLineCursor)      => 'lg-hard-line',
    (LineGroupCursor)     => 'line-group-id',
    ;


#| General viewer for rich text content
class Terminal::Widgets::Viewer::RichText
 does Terminal::Widgets::WrappableBuffer {
    has Terminal::Widgets::HighlightMode:D $.highlight-mode is rw = NoHighlight;
    has Terminal::Widgets::CursorMode:D    $.cursor-mode    is rw = NoCursor;

    method layout-class() { Terminal::Widgets::Layout::RichTextViewer }

    #| Post-process the lines in a (partially-?) visible LineGroup before
    #| display; in this case, highlight any selected line/span
    method post-process-line-group($lg-id, $first-line, $start-line, $last-line, @lines) {
        my $should-process = $!highlight-mode || $!cursor-mode;
        my $selected-id    = %!selected-span-info<line-group-id> // 0;

        if $should-process && $lg-id == $selected-id {
            # Prepare to colorize cursor and highlight region
            my $colorset  = $.terminal.colorset;
            my $c-color   = $!cursor-mode    ?? $colorset.cursor    !! '';
            my $h-color   = $!highlight-mode ?? $colorset.highlight !! '';
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

                # Highlight first if needed before marking cursor
                if $!highlight-mode && $h-color {
                    my sub hl-spans(&should-highlight) {
                        # Process spans as needed
                        my @line = $line.map: {
                            should-highlight($_)
                            ?? .clone(color => color-merge(.color, $h-color))
                            !! $_
                        }

                        # Replace plain line with processed version
                        $line = @line;
                    }

                    given $!highlight-mode {
                        when LineGroupHighlight {
                            hl-spans({True});
                        }
                        when HardLineHighlight {
                            hl-spans({ (my $ss = $^span.string-span) &&
                                       (my $attrs = $ss.attributes) &&
                                       $attrs<lg-hard-line> == $h-target });
                        }
                        when SoftLineHighlight {
                            hl-spans({True}) if $line.first(* === $h-target);
                        }
                        when StringSpanHighlight {
                            hl-spans(*.string-span === $h-target);
                        }
                        when RenderSpanHighlight {
                            hl-spans(* === $h-target);
                        }
                        when GraphemeHighlight { ... }
                        default { !!! "Unknown buffer highlight mode $_" }
                    }
                }

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
