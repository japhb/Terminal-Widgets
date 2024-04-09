# ABSTRACT: Utility classes to assist with translation

unit module Terminal::Widgets::I18N::Translation;

use Terminal::Widgets::TextContent;


#| A translatable (and optionally interpolatable) string that knows its own
#| translation context
class TranslatableString is export {
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
        Terminal::Widgets::TextContent::throw-cannot-stringify(self, 'translate-via', 'a parseable MarkupString');
    }
}


#| Convert translatable content step by step towards a list of RenderSpans
class TranslatableContentRenderer
   is Terminal::Widgets::TextContent::ContentRenderer {
    has $.locale is required;

    #| Convert TranslatableString -> MarkupString and continue rendering
    multi method render(TranslatableString:D $ts) {
        my $ms = $ts.interpolatable ?? $.locale.translate($ts, :%.vars)
                                    !! $.locale.translate($ts);
        self.render($ms)
    }
}


#| Language selection utility methods
class LanguageSelection is export {
    #| Determine list of language codes user prefers
    method user-languages(Str $override?, Str :$default) {
        my Str:D $pref = $override || %*ENV<LANGUAGE> || %*ENV<LANG>
                       || $default || 'en';
        $pref.split(':').map(*.split('.')[0].subst('_', '-'))
    }

    #| Return the best language options from available array according to
    #| preferred array.  Returned language codes are directly available, and
    #| need not be further matched (preferred short codes have been expanded
    #| where needed).
    multi method best-languages(:@preferred, :@available) {
        my $available = @available.classify(*);
        my $shortened = @available.classify(*.split('-')[0]);

        # XXXX: Confirm this is the correct algorithm
        (@preferred.map({ ($available{$_} || $shortened{$_} || Empty).Slip }),
         @preferred.map({ my $s = .split('-')[0];
                          ($available{$s} || Empty).Slip,
                          ($shortened{$s} || Empty).Slip }))
        .flat.unique
    }

    #| Return the best language options from available array according to
    #| user preferences, allowing a default if the user has not specified
    #| a preference.  Returned language codes are directly available, and
    #| need not be further matched; preferred short codes have been
    #| expanded where needed.
    multi method best-languages(@available, Str :$default) {
        my @preferred = self.user-languages(:$default);
        self.best-languages(:@preferred, :@available)
    }
}


# Ensure $*TRANSLATION_CONTEXT exists, even at BEGIN time in the importing module
PROCESS::<$TRANSLATION_CONTEXT> = 'DEFAULT';


#| Set the current $*TRANSLATION_CONTEXT in this dynamic scope
sub prefix:<¢>(Str:D $context) is export {
    $*TRANSLATION_CONTEXT = $context;
}

#| Create a TranslatableString from a simple Str and the $*TRANSLATION_CONTEXT
sub prefix:<¿>(Str:D $string) is export {
    my $context = $*TRANSLATION_CONTEXT // 'DEFAULT';
    TranslatableString.new(:$string, :$context)
}

#| Create a TranslatableString from a _specified_ context and string
sub infix:<¢¿>(Str:D $context, Str:D $string) is export {
    TranslatableString.new(:$string, :$context)
}

#| Set the current TRANSLATION_CONTEXT for a block
sub infix:«¢>»(Str:D $context, &code) is export {
    my $*TRANSLATION_CONTEXT = $context;
    code();
}
