# ABSTRACT: Base class for dynamically building standard widgets

use Terminal::Widgets::Layout;
use Terminal::Widgets::PlainText;
use Terminal::Widgets::Input::Menu;
use Terminal::Widgets::Input::Button;
use Terminal::Widgets::Input::Checkbox;
use Terminal::Widgets::Input::RadioButton;
use Terminal::Widgets::Input::Text;
use Terminal::Widgets::Viewer::Log;


#| Base class for dynamically building widgets, with knowledge of standard library
class Terminal::Widgets::StandardWidgetBuilder {
    #| Map layout nodes with default build rules
    method default-build-nodes() {
        :{
            Terminal::Widgets::Layout::Widget      => Terminal::Widgets::Widget,
            Terminal::Widgets::Layout::PlainText   => Terminal::Widgets::PlainText,
            Terminal::Widgets::Layout::Menu        => Terminal::Widgets::Input::Menu,
            Terminal::Widgets::Layout::Button      => Terminal::Widgets::Input::Button,
            Terminal::Widgets::Layout::Checkbox    => Terminal::Widgets::Input::Checkbox,
            Terminal::Widgets::Layout::RadioButton => Terminal::Widgets::Input::RadioButton,
            Terminal::Widgets::Layout::TextInput   => Terminal::Widgets::Input::Text,
            Terminal::Widgets::Layout::LogViewer   => Terminal::Widgets::Viewer::Log,
        }
    }

    #| Build widgets from the standard widget library based on dynamic layout
    method build-node($node, $geometry) {
        # XXXX: Optimize this away
        my $default-build := self.default-build-nodes;

        do given $node.WHAT {
            when $default-build {
                $default-build{$_}.new(|$geometry, |$node.extra)
            }
            when Terminal::Widgets::Layout::Divider {
                my $style = $node.extra<line-style> || $geometry<parent>.default-box-style;
                if $node.parent && $node.parent.vertical {
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
            default { Nil }
        }
    }
}
