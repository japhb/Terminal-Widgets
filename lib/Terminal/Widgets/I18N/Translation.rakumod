# ABSTRACT: Utility classes to assist with translation

unit module Terminal::Widgets::I18N::Translation;

use Text::MiscUtils::Layout;


#| A translated string that knows what it was translated from and
#| its own duospace width
class TranslatedString is export {
    has       $.original   is required;
    has Str:D $.translated is required;
    has UInt  $!width;

    #| Lazily calculate and cache duospace width
    method width(--> UInt:D) {
        $!width //= duospace-width($!translated)
    }

    #| Stringification is just translated string
    method Str(--> Str:D) { $!translated }

    #| Provide a common method name that provides the TranslatableString
    #| for this string, whether or not it has been translated already
    method translatable() { $!original }
}


#| A string that knows the context for which it should be translated
class TranslatableString is export {
    has Str:D $.string  is required;
    has Str:D $.context is required;
    has %.vars;

    #| Translate this string by looking up its context in a translation table
    multi method translate-via(%translation-table) {
        die 'Context ' ~ $.context.raku ~ ' not found in translation table'
            unless my $in-context = %translation-table{$.context};

        self.translate-via($in-context{$.string} // $.string)
    }

    #| Translate this string by calling a translator function
    multi method translate-via(&translator) {
        self.translate-via(translator(self))
    }

    #| Translate by interpolating variables into a pre-translated string
    multi method translate-via(Str:D $interpolatable) {
        # XXXX: This method doesn't handle \$ or \\$
        my $translated = $interpolatable.contains('$')
                         ?? $interpolatable.subst(/\$(\w+)/,
                                                  { %.vars{$0}
                                                    // '[MISSING TRANSLATION VARIABLE ' ~ (~$0 .raku) ~ ']' },
                                                  :g)
                         !! $interpolatable;

        TranslatedString.new(:$translated, :original(self))
    }

    #| Disallow direct .Str without translation
    method Str() {
        die 'Cannot directly stringify a TranslatableString; use translate-via method instead.';
    }

    #| Provide a common method name that provides the TranslatableString
    #| for this string, whether or not it has been translated already
    method translatable() { self }
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
