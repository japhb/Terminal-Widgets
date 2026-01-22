# ABSTRACT: Base class for dynamically building standard widgets

use Terminal::Widgets::WidgetRegistry;
use Terminal::Widgets::Layout;

# Load all core widget types so they self-register
use Terminal::Widgets::Widget;
use Terminal::Widgets::PlainText;
use Terminal::Widgets::ScrollBar;

use Terminal::Widgets::Input::Menu;
use Terminal::Widgets::Input::Button;
use Terminal::Widgets::Input::Checkbox;
use Terminal::Widgets::Input::RadioButton;
use Terminal::Widgets::Input::ToggleButton;
use Terminal::Widgets::Input::Text;

use Terminal::Widgets::Viewer::Log;
use Terminal::Widgets::Viewer::Tree;
use Terminal::Widgets::Viewer::DirTree;
use Terminal::Widgets::Viewer::RichText;

use Terminal::Widgets::Viz::SmokeChart;


#| Base class for dynamically building widgets
class Terminal::Widgets::StandardWidgetBuilder
 does Terminal::Widgets::WidgetRegistry {
    #| Build widgets from the registered widget library based on dynamic layout
    method build-node($node, $geometry) {
        do given $node.WHAT {
            # XXXX: Temporary workaround while changing content model
            when Terminal::Widgets::Layout::PlainText {
                my %extra = %($node.extra);
                %extra<c> = %extra<color>:delete if %extra<color>:exists;
                Terminal::Widgets::PlainText.new(|$geometry, |%extra)
            }
            when self.layout-exists($_) {
                self.widget-for-layout($_).new(|$geometry, |$node.extra)
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
