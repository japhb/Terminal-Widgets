# ABSTRACT: Plain text content

use Text::MiscUtils::Layout;

use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::TextContent;
use Terminal::Widgets::Layout;
use Terminal::Widgets::SpanBuffer;


#| Layout node for a plain text widget
class Terminal::Widgets::Layout::PlainText
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'plain-text' }

    method default-styles(:$locale!, :$text = '') {
        my @lines = $locale.plain-text($text).lines;

        %( min-h => @lines.elems,
           min-w => 0 max @lines.map({ $locale.width($_) }).max )
    }
}


#| A simple scrollable plain text widget with a default color
class Terminal::Widgets::PlainText
 does Terminal::Widgets::SpanBuffer {
    has Str:D  $.text  = '';
    has Str:D  $.c     = '';
    has Bool:D $.wrap  = False;

    method layout-class() { Terminal::Widgets::Layout::PlainText }

    # Setters that also trigger display refresh
    method set-text(Str:D $!text)                   { self.full-refresh }
    method set-color(Str:D $!c)                     { self.full-refresh }
    method set-content(Str:D $!text, Str:D $!c)     { self.full-refresh }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my $w     = self.content-width;
        my $color = color-merge(self.current-color, $!c);
        my @lines = ($.wrap ?? $.text.lines.map({ wrap-text($w, $_).Slip }).flat
                            !! $.text.lines)
                    .map({ RenderSpan.new(text => $_, :$color), });

        $start ?? @lines[$start..*] !! @lines
    }
}


# Register PlainText as a buildable widget type
Terminal::Widgets::PlainText.register;
