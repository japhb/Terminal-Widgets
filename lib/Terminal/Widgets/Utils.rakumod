# ABSTRACT: Simple utility routines

unit module Terminal::Widgets::Utils;

use Terminal::Print::Grid;
use Text::MiscUtils::Layout;


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
multi rgb-color(Real:D $r, Real:D $g, Real:D $b) is export {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp
    ~(16 + 36 * (my int $ri = floor(5e0 * (my num $rn = $r.Num) + .5e0))
         +  6 * (my int $gi = floor(5e0 * (my num $gn = $g.Num) + .5e0))
         +      (my int $bi = floor(5e0 * (my num $bn = $b.Num) + .5e0)))
}


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
multi rgb-color(num $r, num $g, num $b) is export {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp
    ~(16 + 36 * (my int $ri = floor(5e0 * $r + .5e0))
         +  6 * (my int $gi = floor(5e0 * $g + .5e0))
         +      (my int $bi = floor(5e0 * $b + .5e0)))
}


#| Convert an rgb triplet (each in the 0..1 range) into a single luminance value
multi rgb-luma(Real:D $r, Real:D $g, Real:D $b) is export {
    # 1/4, 11/16, 1/16 RGB luma coefficients (chosen to be between coefficients
    # used by HDTV and HDR standards and also exact with binary arithmetic)
      .2500e0 * (my num $rn = $r.Num)
    + .6875e0 * (my num $rg = $g.Num)
    + .0625e0 * (my num $rb = $b.Num)
}


#| Convert an rgb triplet (each in the 0..1 range) into a single luminance value
multi rgb-luma(num $r, num $g, num $b) is export {
    # 1/4, 11/16, 1/16 RGB luma coefficients (chosen to be between coefficients
    # used by HDTV and HDR standards and also exact with binary arithmetic)
      .2500e0 * $r
    + .6875e0 * $g
    + .0625e0 * $b
}


#| Convert a grayscale value (in the 0..1 range) to a valid cell color
multi gray-color(Real:D $gray) is export {
    # Use the hi-res gray ramp plus true black and white (from the color cube).

    # Note: Due to an off-by-one error in the original xterm ramp mapping, the
    #       gray ramp is *NOT* centered between the black and white ends; here
    #       we choose 1/64 and 61/64 as the crossover points and map the 15/16
    #       between them to the grey ramp.  For more info see:
    #
    # https://github.com/ThomasDickey/xterm-snapshots/blob/master/256colres.pl

    (my num $gn = $gray.Num) <  .015625e0 ??  '16' !!
                         $gn >= .953125e0 ?? '231' !!
                                            ~(232 + (25.6e0 * ($gray - .015625e0)).floor)
}


#| Convert a grayscale value (in the 0..1 range) to a valid cell color
multi gray-color(num $gray) is export {
    # Use the hi-res gray ramp plus true black and white (from the color cube).

    # Note: Due to an off-by-one error in the original xterm ramp mapping, the
    #       gray ramp is *NOT* centered between the black and white ends; here
    #       we choose 1/64 and 61/64 as the crossover points and map the 15/16
    #       between them to the grey ramp.  For more info see:
    #
    # https://github.com/ThomasDickey/xterm-snapshots/blob/master/256colres.pl

    $gray <  .015625e0 ??  '16' !!
    $gray >= .953125e0 ?? '231' !!
                         ~(232 + (25.6e0 * ($gray - .015625e0)).floor)
}


#| Convert an rgb triplet (each in the 0..1 range) to a grayscale cell color
multi gray-color(Real:D $r, Real:D $g, Real:D $b) is export {
    gray-color(rgb-luma($r, $g, $b))
}


#| Convert an rgb triplet (each in the 0..1 range) to a grayscale cell color
multi gray-color(num $r, num $g, num $b) is export {
    gray-color(rgb-luma($r, $g, $b))
}


#| Convert a text block (a single multiline string) into a T::P::Grid
sub make-text-grid($text) is export {
    my @lines = $text.lines;
    my $w     = @lines.map(&duospace-width).max;
    my $h     = @lines.elems;
    my $grid  = Terminal::Print::Grid.new($w, $h);

    $grid.set-span-text(0, $_, @lines[$_]) for ^$h;

    $grid
}
