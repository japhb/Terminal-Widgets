# ABSTRACT: Simple utility routines

unit module Terminal::Widgets::Utils;

use Terminal::Print::Grid;
use Text::MiscUtils::Layout;


#| Convert a text block (a single multiline string) into a T::P::Grid
sub make-text-grid($text) is export {
    my @lines = $text.lines;
    my $w     = @lines.map(&duospace-width).max;
    my $h     = @lines.elems;
    my $grid  = Terminal::Print::Grid.new($w, $h);

    $grid.set-span-text(0, $_, @lines[$_]) for ^$h;

    $grid
}
