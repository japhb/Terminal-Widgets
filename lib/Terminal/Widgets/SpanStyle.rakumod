# ABSTRACT: Per-span text styling

unit module Terminal::Widgets::SpanStyle;

use Terminal::Widgets::Utils::Color;


#| A single styled span with no children (other than its own text)
class Span {
    has Str:D $.color = '';  #= Color/SGR attributes to apply to this span
    has Str:D $.text  = '';  #= Actual (unstyled) textual content

    #| Apply current span attributes on top of parent attributes, returning a
    #| new Span if needed or self if parent attributes were empty.  This method
    #| is used primarily as the base case of SpanTree.flatten.
    method flatten(Str:D $parent-color = '') {
        $parent-color ?? self.new(:$.text, color => color-merge($parent-color, $.color))
                      !! self
    }
}

#| Helper function to build a single Span
sub span(Str:D $color, Str:D $text) is export {
    Span.new(:$color, :$text)
}


#| A (sub-)tree of styled spans
class SpanTree {
    has Str:D $.color = '';  # Color/SGR attributes to apply to this (sub-)tree
    has       @.children;    # Str:D, Span:D, or SpanTree:D children

    #| Convert from tree form to single linear list of Spans for rendering
    method flatten(Str:D $parent-color = '') {
        my $child-base-color = color-merge($parent-color, $.color);
        @.children.map({ $_ ~~ Str ?? span($child-base-color, $_)
                                   !! .flatten($child-base-color) }).flat
    }
}

#| Helper function to build a SpanTree node
multi span-tree(Str:D $color, @children) is export {
    SpanTree.new(:$color, :@children)
}

#| Helper function to build a SpanTree node
multi span-tree(Str:D $color, *@children) is export {
    SpanTree.new(:$color, :@children)
}


#| Valid span-styled content types
subset SpanContent is export where Str|Span|SpanTree;
