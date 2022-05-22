# ABSTRACT: Simple utility routines

unit module Terminal::Widgets::Utils;

use Terminal::Print::Grid;
use Text::MiscUtils::Layout;


#| Convert an rgb triplet (each in the 0..1 range) to a valid cell color
sub rgb-color(Real $r, Real $g, Real $b) is export {
    # Just use the 6x6x6 color cube, ignoring the hi-res gray ramp
    # This formulation is 5x faster than the original; un/boxing sucks
    ~(16 + 36 * (my int $ri = floor(5e0 * (my num $rn = $r) + .5e0))
         +  6 * (my int $gi = floor(5e0 * (my num $gn = $g) + .5e0))
         +      (my int $bi = floor(5e0 * (my num $bn = $b) + .5e0)))
}


#| Convert a grayscale value (in the 0..1 range) to a valid cell color
sub gray-color(Real $gray) is export {
    # Use the hi-res gray ramp plus true black and white
    my $c = $gray <= .012e0 ?? 'black' !!
            $gray >= .953e0 ?? 'white' !!
                               232 + (24e0 * $gray).floor;

    # Cell colors must be stringified
    ~$c
}


#| Convert a text block (a single multiline string) into a T::P::Grid
sub make-text-grid($text) is export {
    my @lines = $text.lines;
    my $w     = @lines.map(*.&duospace-width).max;
    my $h     = @lines.elems;
    my $grid  = Terminal::Print::Grid.new($w, $h);

    $grid.set-span-text(0, $_, @lines[$_]) for ^$h;

    $grid
}
