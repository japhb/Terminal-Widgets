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

    # Expanded edge widths for top, right, bottom, left sides (read only)
    has $.pt is built(False);  # Padding
    has $.pr is built(False);
    has $.pb is built(False);
    has $.pl is built(False);

    has $.bt is built(False);  # Border
    has $.br is built(False);
    has $.bb is built(False);
    has $.bl is built(False);

    has $.mt is built(False);  # Margin
    has $.mr is built(False);
    has $.mb is built(False);
    has $.ml is built(False);

    # Flags indicating whether any sides have non-zero width
    has Bool $.has-padding is built(False);
    has Bool $.has-border  is built(False);
    has Bool $.has-margin  is built(False);
    has Bool $.has-framing is built(False);


    submethod TWEAK() {
        self!set-padding-width($!padding-width);
        self!set-border-width( $!border-width );
        self!set-margin-width( $!margin-width );
        $!has-framing = $!has-margin || $!has-border || $!has-padding;
    }

    multi method resolve-edge-defaults($value) {
        $value xx 4
    }

    multi method resolve-edge-defaults(@ [$t, $r = $t, $b = $t, $l = $r]) {
        $t, $r, $b, $l
    }

    method !set-padding-width(BoxWidth:D $!padding-width) {
        ($!pt, $!pr, $!pb, $!pl) = self.resolve-edge-defaults($!padding-width);
        $!has-padding = ?($!pt || $!pr || $!pb || $!pl);
    }

    method !set-border-width(BoxWidth:D $!border-width) {
        ($!bt, $!br, $!bb, $!bl) = self.resolve-edge-defaults($!border-width);
        $!has-border = ?($!bt || $!br || $!bb || $!bl);
    }

    method !set-margin-width(BoxWidth:D $!margin-width) {
        ($!mt, $!mr, $!mb, $!ml) = self.resolve-edge-defaults($!margin-width);
        $!has-margin = ?($!mt || $!mr || $!mb || $!ml);
    }

    # The math below works out to:
    #
    #      sizing-box
    # box   C    P    B    M
    # C    000  -00  --0  ---
    # P    +00  000  0-0  0--
    # B    ++0  0+0  000  00-
    # M    +++  0++  00+  000

    multi method width-correction(SizingBox:D $box) {
          ($!pl + $!pr) * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + ($!bl + $!br) * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + ($!ml + $!mr) * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }

    multi method height-correction(SizingBox:D $box) {
          ($!pt + $!pb) * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + ($!bt + $!bb) * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + ($!mt + $!mb) * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }

    multi method left-correction(SizingBox:D $box) {
          $!pl * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + $!bl * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + $!ml * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }

    multi method right-correction(SizingBox:D $box) {
          $!pr * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + $!br * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + $!mr * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }

    multi method top-correction(SizingBox:D $box) {
          $!pt * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + $!bt * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + $!mt * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }

    multi method bottom-correction(SizingBox:D $box) {
          $!pb * ((PaddingBox > $!sizing-box) - (PaddingBox > $box))
        + $!bb * ((BorderBox  > $!sizing-box) - (BorderBox  > $box))
        + $!mb * ((MarginBox  > $!sizing-box) - (MarginBox  > $box))
    }

    # Fast shorthands for full correction between MarginBox and ContentBox
    multi method width-correction() {
        $!pl + $!pr + $!bl + $!br + $!ml + $!mr
    }

    multi method height-correction() {
        $!pt + $!pb + $!bt + $!bb + $!mt + $!mb
    }

    multi method left-correction() {
        $!pl + $!bl + $!ml
    }

    multi method right-correction() {
        $!pr + $!br + $!mr
    }

    multi method top-correction() {
        $!pt + $!bt + $!mt
    }

    multi method bottom-correction() {
        $!pb + $!bb + $!mb
    }
}
