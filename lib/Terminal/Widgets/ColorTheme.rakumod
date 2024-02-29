# ABSTRACT: Base class for color/attribute themes

use Terminal::Widgets::Utils::Color;


#| Color selectors for a theme variant, using Terminal::ANSIColor strings
class Terminal::Widgets::ColorSet {
    # Known color selectors
    has Str:D $.text      is required;
    has Str:D $.hint      is required;
    has Str:D $.link      is required;
    has Str:D $.input     is required;
    has Str:D $.focused   is required;
    has Str:D $.blurred   is required;
    has Str:D $.highlight is required;
    has Str:D $.active    is required;
    has Str:D $.disabled  is required;
    has Str:D $.error     is required;

    # Selectors in priority override order, lowest to highest priority
    has @.selector-order  = < text hint link input focused blurred
                              highlight active disabled error >;

    #| Determine current color by merging selectors for all active states
    method current-color(%states) {
        my @states = @.selector-order.map({ $_ if %states{$_} });
        my @colors = @states.map({ self."$_"() });
        color-merge(@colors);
    }
}


#| Variant color sets for a common base color theme
class Terminal::Widgets::ColorTheme {
    has Str:D $.moniker is required;
    has       $.name    is required;
    has       $.desc    is required;

    # XXXX: Not sure I like this method of defining variants
    has Terminal::Widgets::ColorSet:D %.variants;
}
