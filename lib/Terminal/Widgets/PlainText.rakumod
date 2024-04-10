# ABSTRACT: Plain text content

use Text::MiscUtils::Layout;

use Terminal::Widgets::TextContent;
use Terminal::Widgets::SpanBuffer;


#| A simple scrollable plain text widget with a default color
class Terminal::Widgets::PlainText
 does Terminal::Widgets::SpanBuffer {
    has Str:D  $.text  = '';
    has Str:D  $.color = '';
    has Bool:D $.wrap  = False;

    # Setters that also trigger display refresh
    method set-text(Str:D $!text)                   { self.full-refresh }
    method set-color(Str:D $!color)                 { self.full-refresh }
    method set-content(Str:D $!text, Str:D $!color) { self.full-refresh }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my $w     = self.content-width;
        my @lines = ($.wrap ?? $.text.lines.map({ wrap-text($w, $_).Slip }).flat
                            !! $.text.lines)
                    .map({ RenderSpan.new(text => $_, :$.color), });

        $start ?? @lines[$start..*] !! @lines
    }
}
