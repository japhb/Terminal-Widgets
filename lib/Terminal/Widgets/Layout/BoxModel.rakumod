# ABSTRACT: Basic CSS-style box model (content, padding, border, margin)

unit module Terminal::Widgets::Layout::BoxModel;


#| The box layer that is being directly managed
#| (the rest adapt based on padding, border, and margin widths)
enum SizingBox is export < ContentBox PaddingBox BorderBox MarginBox >;


#| Padding, border, and margin widths, as either a single number or a list in
#| top, right, bottom, left order (with defaults 0, $top, $top, $right)
subset BoxWidth of Any is export where UInt | Positional;


#| A basic CSS-style box model, with concentric layers of content, padding,
#| border, and margin
role BoxModel {
    #| Which box are width and height settings actually controlling?
    has SizingBox:D $.sizing-box    = ContentBox;
    has BoxWidth:D  $.padding-width = 0;
    has BoxWidth:D  $.border-width  = 0;
    has BoxWidth:D  $.margin-width  = 0;

    # Pre-defaulted edge widths for top, right, bottom, left sides
    has ($!pt, $!pr, $!pb, $!pl);  # Padding
    has ($!bt, $!br, $!bb, $!bl);  # Border
    has ($!mt, $!mr, $!mb, $!ml);  # Margin


    submethod TWEAK() {
        self!set-padding-width($!padding-width);
        self!set-border-width( $!border-width );
        self!set-margin-width( $!margin-width );
    }

    multi method resolve-edge-defaults($value) {
        $value xx 4
    }

    multi method resolve-edge-defaults(@ [$t, $r = $t, $b = $t, $l = $r]) {
        $t, $r, $b, $l
    }

    method !set-padding-width(BoxWidth:D $!padding-width) {
        ($!pt, $!pr, $!pb, $!pl) = self.resolve-edge-defaults($!padding-width);
    }

    method !set-border-width(BoxWidth:D $!border-width) {
        ($!bt, $!br, $!bb, $!bl) = self.resolve-edge-defaults($!border-width);
    }

    method !set-margin-width(BoxWidth:D $!margin-width) {
        ($!mt, $!mr, $!mb, $!ml) = self.resolve-edge-defaults($!margin-width);
    }

    # The math below works out to:
    #
    #      sizing-box
    # box   C    P    B    M
    # C    000  -00  --0  ---
    # P    +00  000  0-0  0--
    # B    ++0  0+0  000  00-
    # M    +++  0++  00+  000

    method width-correction(SizingBox:D $box) {
          ($!pl + $!pr) * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + ($!bl + $!br) * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + ($!ml + $!mr) * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }

    method height-correction(SizingBox:D $box) {
          ($!pt + $!pb) * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + ($!bt + $!bb) * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + ($!mt + $!mb) * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }
}
