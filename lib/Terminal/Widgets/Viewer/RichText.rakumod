# ABSTRACT: General viewer for rich text content

use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::Layout;
use Terminal::Widgets::WrappableBuffer;


#| Layout node for a rich text viewer widget
class Terminal::Widgets::Layout::RichTextViewer
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'rich-text-viewer' }
}


#| General viewer for rich text content
class Terminal::Widgets::Viewer::RichText
 does Terminal::Widgets::WrappableBuffer {
    method layout-class() { Terminal::Widgets::Layout::RichTextViewer }

    #| Post-process the lines in a (partially-?) visible LineGroup before
    #| display; in this case, highlight any selected line/span
    method post-process-line-group($lg-id, $first-line, $start-line, $last-line, @lines) {
        my $selected-id = %!selected-span-info<line-group-id> // 0;
        if $selected-id == $lg-id {
            my $highlight = $.terminal.colorset.highlight;
            my $pos       = 0 max $start-line - $first-line;
            my $end       = @lines.elems;

            # Move lines before start-line over unchanged
            my @processed = @lines[^$pos];

            # Process remaining lines until past $last-line
            while $pos < $end {
                my $cur-line = $first-line + $pos;
                last if $cur-line > $last-line;

                my $line = @lines[$pos++];
                my @line;
                for @$line -> $span {
                    if $span === %!selected-span-info<span> {
                        my $color = color-merge($span.color, $highlight);
                        @line.push($span.clone(:$color));
                    }
                    else {
                        @line.push($span);
                    }
                }

                @processed.push(@line);
            }

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
