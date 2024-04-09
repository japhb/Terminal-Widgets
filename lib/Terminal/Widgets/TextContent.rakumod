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
class RenderSpan {
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
                  // '[MISSING TRANSLATION VARIABLE ' ~ $.var-name.raku ~ ']';
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
        my %child-base-attributes = |%parent-attributes, |%.attributes;
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


#| A translatable (and optionally interpolatable) string that knows its own
#| translation context
class TranslatableString {
    has Str:D  $.string  is required;
    has Str:D  $.context is required;
    has Bool:D $.interpolatable = False;

    #| Translate this string by looking up its context in a translation table
    multi method translate-via(%translation-table, :%vars --> MarkupString:D) {
        die 'Context ' ~ $.context.raku ~ ' not found in translation table'
            unless my $in-context = %translation-table{$.context};

        self.translate-via($in-context{$.string} // $.string, :%vars)
    }

    #| Translate this string by calling a translator function
    multi method translate-via(&translator, :%vars --> MarkupString:D) {
        self.translate-via(translator(self, :%vars), :%vars)
    }

    #| Base case for translate-via: we've reached a raw Str:D representing
    #| the translation, and need to wrap it into a MarkupString for further
    #| processing.
    multi method translate-via(Str:D $translated --> MarkupString:D) {
        MarkupString.new(string => $translated, :$.interpolatable)
    }

    #| Disallow direct .Str without translation
    method Str() {
        throw-cannot-stringify(self, 'translate-via', 'a parseable MarkupString');
    }
}
