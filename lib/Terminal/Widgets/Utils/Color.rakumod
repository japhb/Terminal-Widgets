# ABSTRACT: Simple color utility routines

unit module Terminal::Widgets::Utils::Color;


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
multi rgb-color-flat(Real:D $r, Real:D $g, Real:D $b) is export {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp.
    # NOTE: Ignores uneven spacing of xterm-256 color cube for speed.

    ~(16 + 36 * (my int $ri = floor(5e0 * (my num $rn = $r.Num) + .5e0))
         +  6 * (my int $gi = floor(5e0 * (my num $gn = $g.Num) + .5e0))
         +      (my int $bi = floor(5e0 * (my num $bn = $b.Num) + .5e0)))
}


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
multi rgb-color-flat(num $r, num $g, num $b) is export {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp.
    # NOTE: Ignores uneven spacing of xterm-256 color cube for speed.

    ~(16 + 36 * (my int $ri = floor(5e0 * $r + .5e0))
         +  6 * (my int $gi = floor(5e0 * $g + .5e0))
         +      (my int $bi = floor(5e0 * $b + .5e0)))
}


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
multi rgb-color(Real:D $r, Real:D $g, Real:D $b) is export {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp.

    # NOTE: The xterm-256 color cube is *NOT* evenly spaced along the axes;
    #       rather, there is a very large jump between black and the first
    #       visible color in each primary, and smaller jumps thereafter.

    ~(16 + 36 * (my int $ri = (my num $rn = $r.Num) < .45098e0
                              ?? my int $rc = $rn >= .1875e0
                              !! my int $rf = floor(6.375e0 * $rn - .875e0))
         +  6 * (my int $gi = (my num $gn = $g.Num) < .45098e0
                              ?? my int $gc = $gn >= .1875e0
                              !! my int $gf = floor(6.375e0 * $gn - .875e0))
         +      (my int $bi = (my num $bn = $b.Num) < .45098e0
                              ?? my int $bc = $bn >= .1875e0
                              !! my int $bf = floor(6.375e0 * $bn - .875e0)))
}


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
multi rgb-color(num $r, num $g, num $b) is export {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp.

    # NOTE: The xterm-256 color cube is *NOT* evenly spaced along the axes;
    #       rather, there is a very large jump between black and the first
    #       visible color in each primary, and smaller jumps thereafter.

    ~(16 + 36 * (my int $ri = $r < .45098e0 ?? my int $rc = $r >= .1875e0
                                            !! my int $rf = floor(6.375e0 * $r - .875e0))
         +  6 * (my int $gi = $g < .45098e0 ?? my int $gc = $g >= .1875e0
                                            !! my int $gf = floor(6.375e0 * $g - .875e0))
         +      (my int $bi = $b < .45098e0 ?? my int $bc = $b >= .1875e0
                                            !! my int $bf = floor(6.375e0 * $b - .875e0)))
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
                        ~(232 + my int $g = floor(25.6e0 * ($gn - .015625e0)))
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
                       ~(232 + my int $g = floor(25.6e0 * ($gray - .015625e0)))
}


#| Convert an rgb triplet (each in the 0..1 range) to a grayscale cell color
multi gray-color(Real:D $r, Real:D $g, Real:D $b) is export {
    gray-color(rgb-luma($r, $g, $b))
}


#| Convert an rgb triplet (each in the 0..1 range) to a grayscale cell color
multi gray-color(num $r, num $g, num $b) is export {
    gray-color(rgb-luma($r, $g, $b))
}


#| Merge color strings together and simplify result, with later settings
#| overriding earlier ones.  Note that simplification is incomplete for
#| performance reasons.
multi sub color-merge(@colors) is export {
    # Split into individual SGR descriptors
    my @split = @colors.join(' ').words.reverse;

    # If there are any resets, only keep the last reset and the remaining
    # descriptors after it
    my $reset = @split.first('reset', :k);
    @split.splice($reset + 1) if $reset.defined;

    # Avoid further work for trivial cases; otherwise, actually calc overrides
    @split <= 1 ?? @split[0] // ''
                !! do {
        # Separate background from others
        my $background = @split.first(*.starts-with('on_'));
        my @others     = @split.grep(!*.starts-with('on_')).unique.reverse;
        @others.push($background) if $background;

        # Final color info!
        @others.join(' ')
    }
}


#| Merge color strings together and simplify result, with later settings
#| overriding earlier ones.  Note that simplification is incomplete for
#| performance reasons.
multi sub color-merge(*@colors) is export {
    color-merge(@colors)
}
