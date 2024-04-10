# ABSTRACT: Roles and Classes that together form the text content model

unit module Terminal::Widgets::TextContent;

use Text::MiscUtils::Layout;


#| An exception preventing stringification for content that requires more processing
class X::CannotStringify is Exception {
    has       $.type              is required;
    has Str:D $.conversion-method is required;
    has Str:D $.conversion-result is required;

    method message() {
        'Cannot directly stringify ' ~ $.type.^name ~ '; use '
        ~ $.conversion-method ~ ' method to convert to '
        ~ $.conversion-result ~ ' instead.'
    }
}


#| Convenience helper to throw X::CannotStringify easily
sub throw-cannot-stringify($type, $conversion-method, $conversion-result) {
    X::CannotStringify.new(:$type, :$conversion-method, :$conversion-result).throw
}


#| A directly renderable styled text span
class RenderSpan is export {
    # XXXX: Include an ID or reference marker of some type to handle user
    #       interaction with the rendered span?

    has Str:D $.color = '';
    has Str:D $.text  = '';
    has UInt  $!width;

    #| Lazily calculate and cache duospace width
    method width(--> UInt:D) {
        $!width //= duospace-width($!text)
    }
}


#| A semantic span within a SpanTree (a StringSpan or InterpolantSpan)
role SemanticSpan { }


#| Merge together parent and child attribute hashes
sub merge-attributes(%parent, %child) {
    # XXXX: For now just flatten, but may need to be smarter about certain keys
    %(|%parent, |%child)
}


#| A plain string and associated attributes needed during rendering
class StringSpan does SemanticSpan {
    has Str:D $.string is required;
    has       %.attributes;

    #| Render the string into a RenderSpan according to its attributes
    method render(--> RenderSpan:D) {
        # XXXX: Hack: Just transfer over the color attribute
        RenderSpan.new(text => $.string, color => %.attributes<color> // '')
    }

    #| Apply current span attributes on top of parent attributes, returning a
    #| new StringSpan if needed or self if parent attributes were empty.
    #| This method is used primarily as a base case for SpanTree.flatten.
    method flatten(%parent-attributes? --> StringSpan:D) {
        %parent-attributes ?? do {
            my $attributes = merge-attributes(%parent-attributes, %.attributes);
            self.new(:$.string, :$attributes)
        }
                           !! self
    }

    #| Disallow direct .Str without rendering
    method Str() {
        throw-cannot-stringify(self, 'render', 'a drawable RenderSpan');
    }
}


#| A single interpolant consisting of a variable name and associated attributes
#| and interpolation flags
class InterpolantSpan does SemanticSpan {
    has Str:D $.var-name is required;
    has       %.flags;
    has       %.attributes;

    #| Interpolate a variable according to its local flags (e.g. formatting)
    #| and return a basic StringSpan instead.
    #  XXXX: Should this require just a *single* variable?  Or is there value
    #        in allowing flags to pull information from other vars?  But if so,
    #        *which* other variables?  Is this encoded in the flag info?
    method interpolate(%vars --> StringSpan:D) {
        # XXXX: Hack ignoring flags completely for now
        my $string = %vars{$.var-name}
                  // '[MISSING INTERPOLATION VARIABLE ' ~ $.var-name.raku ~ ']';
        StringSpan.new(:$.string, :%.attributes);
    }

    #| Apply current span attributes on top of parent attributes, returning a
    #| new InterpolantSpan if needed or self if parent attributes were empty.
    #| This method is used primarily as a base case for SpanTree.flatten.
    method flatten(%parent-attributes? --> InterpolantSpan:D) {
        %parent-attributes ?? do {
            my $attributes = merge-attributes(%parent-attributes, %.attributes);
            self.new(:$.var-name, :%.flags, :$attributes)
        }
                           !! self
    }

    #| Disallow direct .Str without interpolating
    method Str() {
        throw-cannot-stringify(self, 'interpolate', 'a renderable StringSpan');
    }
}


#| An attribute-carrying tree of spans with SemanticSpan leaves
class SpanTree {
    my subset SpanTreeNode where SemanticSpan | SpanTree;

    has SpanTreeNode:D @.children;
    has                %.attributes;

    #| Flatten the SpanTree into a single list of SemanticSpans, with parent
    #| attributes fanned out to children; child node attributes are allowed
    #| to override parent attributes or add new ones.
    method flatten(%parent-attributes?) {
        my %child-base-attributes = merge-attributes(%parent-attributes,
                                                     %.attributes);
        @.children.map(*.flatten(%child-base-attributes)).flat
    }

    #| Disallow direct .Str without flattening
    method Str() {
        throw-cannot-stringify(self, 'flatten',
                               'a list of interpolatable or renderable SemanticSpans');
    }
}


#| A parseable (and optionally interpolatable) string containing markup
class MarkupString is export {
    has Str:D  $.string is required;
    has Bool:D $.interpolatable = False;

    #| Parse markup within $.string, producing a SpanTree containing a mix of
    #| InterpolantSpans and StringSpans at the leaves according to the value of
    #| $.interpolatable and the parsed markup itself.
    method parse(--> SpanTree:D) {
        # XXXX: Hack returning a SpanTree with just a single StringSpan,
        #       completely ignoring markup and interpolants
        SpanTree.new(children => (StringSpan.new(:$.string),))
    }

    #| Disallow direct .Str without parsing
    method Str() {
        throw-cannot-stringify(self, 'parse', 'a flattenable SpanTree');
    }
}


#| Convert content step by step towards a list of RenderSpans
class ContentRenderer {
    has %.vars;

    #| Convert MarkupString -> SpanTree and continue rendering
    multi method render(MarkupString:D $ms) {
        my $st = $ms.parse;
        self.render($st)
    }

    #| Convert SpanTree -> flattened list of StringSpans and continue rendering
    multi method render(SpanTree:D $st) {
        # XXXX: Performance could be improved by inlining the render pass
        #       inside the map, but this is easier to test at the moment.
        my @flat-ss = $st.flatten.map: {
            .isa(InterpolantSpan) ?? .interpolate(%.vars) !! $_;
        };
        self.render(@flat-ss)
    }

    #| Convert a list of StringSpans -> a list of RenderSpans
    #  XXXX: This does not constrain the types of entries in @flat-ss
    multi method render(@flat-ss) {
        @flat-ss.map(*.render)
    }

    #| Convert a single StringSpan -> a single RenderSpan
    multi method render(StringSpan:D $ss) {
        $ss.render
    }

    #| Convert a single Str -> a single RenderSpan (for compatibility)
    multi method render(Str:D $text) {
        RenderSpan.new(:$text)
    }

    #| Trivial identity case for plain-text method
    multi method plain-text(Str:D $content --> Str:D) {
        $content
    }

    #| Plain text (--> Str:D) rendering for a piece of content
    #  XXXX: Type of $content is not constrained
    multi method plain-text($content --> Str:D) {
        self.render($content).map(*.text).join
    }

    #| Total duospace width for a piece of content
    #  XXXX: Type of $content is not constrained
    method width($content) {
        self.render($content).map(*.width).sum
    }
}
