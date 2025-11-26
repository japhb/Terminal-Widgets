# ABSTRACT: Per-terminal user locale information

use Terminal::Widgets::I18N::Translation;

constant ContentRenderer =
    Terminal::Widgets::I18N::Translation::TranslatableContentRenderer;


#| Per-terminal user locale info and locale/language aware utility methods
class Terminal::Widgets::I18N::Locale {
    has ContentRenderer:D $.renderer .= new(locale => self);
    has %.string-table;

    multi method translate(TranslatableString:D $string, :%vars) {
        %!string-table ?? $string.translate-via(%!string-table, :%vars)
                       !! $string.translate-via($string.string, :%vars)
    }
    multi method translate($string) { $string }

    method flat-string-spans($content) { $.renderer.flat-string-spans($content) }
    method flat-spans($content)        { $.renderer.flat-spans($content) }
    method plain-text($content)        { $.renderer.plain-text($content) }
    method render($content)            { $.renderer.render($content) }
    method width($content)             { $.renderer.width($content) }
}
