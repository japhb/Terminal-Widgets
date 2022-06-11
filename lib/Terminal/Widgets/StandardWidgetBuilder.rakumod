# ABSTRACT: Base class for dynamically building standard widgets

use Terminal::Widgets::Layout;
use Terminal::Widgets::Input::Text;


#| Base class for dynamically building widgets, with knowledge of standard library
class Terminal::Widgets::StandardWidgetBuilder {
    #| Build widgets from the standard widget library based on dynamic layout
    method build-node($node, $geometry) {
        do given $node {
            when *.widget {
                # Widget already built, just update its geometry
                .widget.update-geometry(|$geometry)
            }
            when Terminal::Widgets::Layout::Divider {
                if .parent && .parent.vertical {
                    my $x1 = $geometry<x>;
                    my $x2 = $x1 + $geometry<w> - 1;
                    my $y  = $geometry<y>;
                    $geometry<parent>.draw-hline($x1, $x2, $y, |.extra);
                }
                else {
                    my $x  = $geometry<x>;
                    my $y1 = $geometry<y>;
                    my $y2 = $y1 + $geometry<h> - 1;
                    $geometry<parent>.draw-vline($x, $y1, $y2, |.extra);
                }
            }
            when Terminal::Widgets::Layout::TextInput {
                Terminal::Widgets::Input::Text.new(|$geometry, |.extra)
            }
            default { Nil }
        }
    }
}
