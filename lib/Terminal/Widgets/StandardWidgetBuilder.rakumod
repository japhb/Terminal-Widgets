# ABSTRACT: Base class for dynamically building standard widgets

use Terminal::Widgets::Layout;
use Terminal::Widgets::Input::Button;
use Terminal::Widgets::Input::Checkbox;
use Terminal::Widgets::Input::RadioButton;
use Terminal::Widgets::Input::Text;
use Terminal::Widgets::Viewer::Log;


#| Base class for dynamically building widgets, with knowledge of standard library
class Terminal::Widgets::StandardWidgetBuilder {
    #| Build widgets from the standard widget library based on dynamic layout
    method build-node($node, $geometry) {
        do given $node {
            when Terminal::Widgets::Layout::Divider {
                my $style = .extra<line-style> || $geometry<parent>.default-box-style;
                if .parent && .parent.vertical {
                    my $x1 = $geometry<x>;
                    my $x2 = $x1 + $geometry<w> - 1;
                    my $y  = $geometry<y>;
                    $geometry<parent>.draw-hline($x1, $x2, $y, :$style);
                }
                else {
                    my $x  = $geometry<x>;
                    my $y1 = $geometry<y>;
                    my $y2 = $y1 + $geometry<h> - 1;
                    $geometry<parent>.draw-vline($x, $y1, $y2, :$style);
                }
            }
            when Terminal::Widgets::Layout::LogViewer {
                Terminal::Widgets::Viewer::Log.new(|$geometry, |.extra)
            }
            when Terminal::Widgets::Layout::Menu {
                Terminal::Widgets::Input::Menu.new(|$geometry, |.extra)
            }
            when Terminal::Widgets::Layout::Button {
                Terminal::Widgets::Input::Button.new(|$geometry, |.extra)
            }
            when Terminal::Widgets::Layout::Checkbox {
                Terminal::Widgets::Input::Checkbox.new(|$geometry, |.extra)
            }
            when Terminal::Widgets::Layout::RadioButton {
                Terminal::Widgets::Input::RadioButton.new(|$geometry, |.extra)
            }
            when Terminal::Widgets::Layout::TextInput {
                Terminal::Widgets::Input::Text.new(|$geometry, |.extra)
            }
            default { Nil }
        }
    }
}
