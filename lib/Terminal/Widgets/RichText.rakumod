# ABSTRACT: Rich text content

use Text::MiscUtils::Layout;

use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::TextContent;
use Terminal::Widgets::Layout;
use Terminal::Widgets::SpanBuffer;

constant TC = Terminal::Widgets::TextContent;

#| Layout node for a rich text widget
class Terminal::Widgets::Layout::RichText
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'rich-text' }

    method default-styles(:$locale!, :$content = '') {
        my @lines = $locale.plain-text($content).lines;

        %( min-h => @lines.elems,
           min-w => 0 max @lines.map({ $locale.width($_) }).max )
    }
}

#| A simple scrollable plain text widget with a default color
class Terminal::Widgets::RichText
 does Terminal::Widgets::SpanBuffer {
    has TextContent:D $.content = '';

    method layout-class() { Terminal::Widgets::Layout::RichText }

    # Setters that also trigger display refresh
    method set-content(TextContent:D $!content)     { self.full-refresh }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my $as-tree = $!content ~~ TC::SpanTree ?? $!content !! TC::span-tree($!content);
        my $colored = TC::span-tree($as-tree, color => self.current-color);
        my @lines = $as-tree.lines.map: -> $line {
            $line.map: *.render;
        };
        $start ?? @lines[$start..*] !! @lines
    }
}


# Register RichText as a buildable widget type
Terminal::Widgets::RichText.register;
