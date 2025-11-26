# ABSTRACT: Roles and Classes that together form the text content model

unit module Terminal::Widgets::TextContent;

use Text::MiscUtils::Layout;
use Terminal::ANSIColor;

use Terminal::Widgets::Utils::Color;


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
sub throw-cannot-stringify($type, $conversion-method, $conversion-result) is export {
    X::CannotStringify.new(:$type, :$conversion-method, :$conversion-result).throw
}


# Forward declaration
class StringSpan { ... }

#| A directly renderable styled text span, optionally remembering the
#| StringSpan it was rendered from (providing a path to StringSpan.attributes)
class RenderSpan is export {
    has StringSpan $.string-span;
    has Str:D      $.color = '';
    has Str:D      $.text  = '';
    has UInt       $!width;

    #| Lazily calculate and cache duospace width
    method width(--> UInt:D) {
        $!width //= duospace-width-core($!text, 0)
    }

    #| Break a single RenderSpan into list of RenderSpans, each containing only
    #| one line (delimited by textual newlines as usual for Str.lines)
    method lines(Bool:D :$chomp = True) {
        $.text.lines(:$chomp).map({ RenderSpan.new(text => $_, :$.color, :$.string-span) })
    }

    #| Stringify to an SGR-escaped string instead of rendering into a widget's
    #| content area (use Widget.draw-line-spans for that)
    method Str(--> Str:D) {
        colored($!text, $!color)
    }
}


#| Any kind of semantic (non-rendered) textual content
role SemanticText is export { }

#| A semantic span within a SpanTree (a StringSpan or InterpolantSpan)
role SemanticSpan does SemanticText { }

#| General text content (semantic or rendered)
subset TextContent is export where Str | RenderSpan | SemanticText;


#| Merge together parent and child attribute hashes
sub merge-attributes(%parent, %child) {
    my %merged = |%parent, |%child;
    %merged<color> = color-merge(%parent<color>, %child<color>)
                              if %parent<color> && (%child<color>:exists);
    %merged
}


#| A plain string and associated attributes needed during rendering
class StringSpan does SemanticSpan {
    has Str:D $.string is required;
    has       %.attributes;

    #| Render the string into a RenderSpan according to its attributes
    method render(--> RenderSpan:D) {
        # XXXX: Hack: Just transfer over the color attribute
        RenderSpan.new(string-span => self, text => $.string,
                       color => %.attributes<color> // '')
    }

    #| Apply current span attributes on top of parent attributes, returning a
    #| new StringSpan if needed or self if parent attributes were empty.
    #| This method is used primarily as a base case for SpanTree.flatten.
    method flatten(%parent-attributes? --> StringSpan:D) {
        %parent-attributes
        ?? self.clone(attributes => merge-attributes(%parent-attributes, %.attributes))
        !! self
    }

    #| Break a single StringSpan into list of StringSpans, each containing only
    #| one line (delimited by textual newlines as usual for Str.lines)
    method lines(Bool:D :$chomp = True) {
        $.string.lines(:$chomp).map({ StringSpan.new(string => $_, :%.attributes) })
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
        %parent-attributes
        ?? self.clone(attributes => merge-attributes(%parent-attributes, %.attributes))
        !! self
    }

    #| Disallow direct .Str without interpolating
    method Str() {
        throw-cannot-stringify(self, 'interpolate', 'a renderable StringSpan');
    }
}


#| An attribute-carrying tree of spans with SemanticSpan leaves
class SpanTree does SemanticText {
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

    #| Convert from arbitrary tree form to a sequence of Arrays, each of which
    #| contains all the flattened StringSpans of a single (newline-delimited) line
    method lines(Bool:D :$chomp = True) {
        my @spans;
        # XXXX: This should go through the ContentRenderer!
        gather for self.flatten.map(*.lines(:!chomp)).flat {
            if .string.ends-with($?NL) {
                @spans.push($chomp ?? StringSpan.new(string => .string.chomp,
                                                     attributes => .attributes)
                                   !! $_);
                take @spans.clone;
                @spans = ();
            }
            else {
                @spans.push($_)
            }
            LAST take @spans if @spans;
        }
    }

    #| Disallow direct .Str without flattening
    method Str() {
        throw-cannot-stringify(self, 'flatten',
                               'a list of interpolatable or renderable SemanticSpans');
    }
}


#| A parseable (and optionally interpolatable) string containing markup
class MarkupString does SemanticText is export {
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


# Helper functions to build spans/trees

#| Helper function to build a RenderSpan, ready for Widget.render-line-spans
our sub render-span(Str:D $text = '', Str:D $color = '',
                    StringSpan :$string-span) is export {
    RenderSpan.new(:$text, :$color, :$string-span)
}

#| Helper function to return a cached StringSpan containing
#| ONLY padding spaces and no attributes of its own
our sub pad-span(UInt:D $pad) is export {
    state @pad-cache;
    @pad-cache[$pad] //= StringSpan.new(string => ' ' x $pad)
}

#| Helper function to build a StringSpan (a SemanticSpan with NO interpolants)
our sub string-span(Str:D $string, *%attributes) is export {
    StringSpan.new(:$string, :%attributes)
}

#| Helper function to build an InterpolantSpan (a SemanticSpan for a single variable)
our sub interpolant-span(Str:D $var-name, :%flags, *%attributes) is export {
    InterpolantSpan.new(:$var-name :%flags, :%attributes)
}

#| Helper function to build up a SpanTree with SemanticSpan leaves
our sub span-tree(*@children, *%attributes) is export {
    SpanTree.new(:@children, :%attributes)
}

#| Helper function to turn a plain Str into a parseable MarkupString
our sub markup-string(Str:D $string, Bool:D :$interpolatable = False) is export {
    MarkupString.new(:$string, :$interpolatable)
}


#| Convert content step by step towards a list of RenderSpans
class ContentRenderer {
    has %.vars;


    ### span-tree: PARSE TO SpanTree AND STOP

    #| Convert MarkupString -> SpanTree and stop (so the parse can be cached)
    multi method span-tree(MarkupString:D $ms) {
        $ms.parse
    }


    ### flat-spans: PARSE TO SpanTree, FLATTEN, AND STOP

    #| Convert MarkupString -> flat list of SemanticSpans and stop,
    #| so the parse and flatten can be cached
    multi method flat-spans(MarkupString:D $ms) {
        $ms.parse.flatten
    }

    #| Convert SpanTree -> flat list of SemanticSpans and stop
    multi method flat-spans(SpanTree:D $st) {
        $st.flatten
    }

    #| Pass through existing SemanticSpan
    multi method flat-spans(SemanticSpan:D $ss) {
        $ss
    }

    #| Convert a Str to a StringSpan for convenience
    multi method flat-spans(Str:D $str) {
        string-span($str)
    }


    ### flat-string-spans: PARSE TO SpanTree, FLATTEN, INTERPOLATE, AND STOP

    #| Convert MarkupString -> flat list of SemanticSpans, interpolate vars
    #| for any InterpolantSpans in the list, giving a flat list of StringSpans
    multi method flat-string-spans(MarkupString:D $ms) {
        $ms.parse.flatten.map: {
            .isa(InterpolantSpan) ?? .interpolate(%.vars) !! $_;
        };
    }

    #| Flatten SpanTree -> list of SemanticSpans, interpolate vars for any
    #| InterpolantSpans in the list, giving a flat list of StringSpans
    multi method flat-string-spans(SpanTree:D $st) {
        $st.flatten.map: {
            .isa(InterpolantSpan) ?? .interpolate(%.vars) !! $_;
        };
    }

    #| Interpolate InterpolantSpan and pass through resulting StringSpan
    multi method flat-string-spans(InterpolantSpan:D $is) {
        $is.interpolate(%.vars)
    }

    #| Passthrough existing StringSpan
    multi method flat-string-spans(StringSpan:D $ss) {
        $ss
    }

    #| Convert a Str to a StringSpan for convenience
    multi method flat-string-spans(Str:D $str) {
        string-span($str)
    }


    ### render: RENDER ALL THE WAY TO RenderSpans

    #| Convert MarkupString -> SpanTree and continue rendering
    multi method render(MarkupString:D $ms) {
        my $st = $ms.parse;
        self.render($st)
    }

    #| Convert SpanTree -> flattened list of RenderSpans
    multi method render(SpanTree:D $st) {
        $st.flatten.map({
            .isa(InterpolantSpan) ?? .interpolate(%.vars).render
                                  !! .render
        })
    }

    #| Convert a list of StringSpans -> a list of RenderSpans
    #  XXXX: This does not constrain the types of entries in @flat-ss
    multi method render(@flat-ss) {
        @flat-ss.map(*.render)
    }

    #| Convert a single StringSpan -> a single RenderSpan
    multi method render(StringSpan:D $ss --> RenderSpan:D) {
        $ss.render
    }

    #| Convert a single Str -> a single RenderSpan (for compatibility)
    multi method render(Str:D $text) {
        RenderSpan.new(:$text)
    }


    ### plain-text: RENDER AND CONVERT TO Str

    #| Trivial identity case for plain-text method
    multi method plain-text(Str:D $content --> Str:D) {
        $content
    }

    #| Plain text (--> Str:D) rendering for a piece of content
    #  XXXX: Type of $content is not constrained
    multi method plain-text($content --> Str:D) {
        self.render($content).map(*.text).join
    }


    ### width: RENDER AND SUM DUOSPACE WIDTH

    #| Total duospace width for a piece of content
    #  XXXX: Type of $content is not constrained
    method width($content --> UInt:D) {
        self.render($content).map(*.width).sum
    }
}
