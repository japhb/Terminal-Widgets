# ABSTRACT: Per-terminal user locale information

use Text::MiscUtils::Layout;
use Terminal::Widgets::I18N::Translation;


#| Per-terminal user locale info and locale/language aware utility methods
class Terminal::Widgets::I18N::Locale {
    has %.string-table;

    multi method translate(TranslatableString:D $string) {
        %!string-table ?? $string.translate-via(%!string-table)
                       !! $string.translate-via($string.string)
    }
    multi method translate($string) { $string }

    multi method width(TranslatableString:D $string) {
        self.translate($string).width
    }
    multi method width(TranslatedString:D $string) { $string.width }
    multi method width(Str:D $string) { duospace-width($string) }
}
