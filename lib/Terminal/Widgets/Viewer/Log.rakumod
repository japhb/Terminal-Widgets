# ABSTRACT: Simple auto-scrolling log viewer

use Text::MiscUtils::Layout;

use Terminal::Widgets::Widget;
use Terminal::Widgets::SpanStyle;


#| Simple auto-scrolling log viewer
class Terminal::Widgets::Viewer::Log
   is Terminal::Widgets::Widget {
    has UInt:D $.scroll-pos = 0;
    has @.log;

    #| Add a single entry (styled content or plain text) to the log
    method add-entry(SpanContent $content) {
        $!scroll-pos += 1 if $!scroll-pos == @!log;
        @!log.push($content);
    }

    #| Refresh display
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-framing;

        # Print most recent content-height wrapped lines
        my $layout = self.layout.computed;
        my $l      = $layout.left-correction;
        my $t      = $layout.top-correction;
        my $w      = $.w - $layout.width-correction;
        my $h      = $.h - $layout.height-correction;
        my $top    = 0 max $.scroll-pos - $h;

        for ^$h {
            my $entry = @!log[$top + $_] // '';
            my $x     = $l;
            my $y     = $t + $_;
            for self.spans($entry) {
                $.grid.set-span($x, $y, .text, .color);
                $x += duospace-width(.text);
            }
        }

        self.composite(:$print);
    }

    #| Determine individual subspans for a log entry's content
    method spans($entry) {
        $entry ~~ Str ?? span('', $entry) !! $entry.flatten
    }
}
