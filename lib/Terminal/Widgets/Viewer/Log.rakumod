# ABSTRACT: Simple auto-scrolling log viewer

use Terminal::Widgets::Widget;


#| Simple auto-scrolling log viewer
class Terminal::Widgets::Viewer::Log
   is Terminal::Widgets::Widget {
    has UInt:D $.scroll-pos = 0;
    has @.log;

    #| Add a single text entry to the log
    method add-entry($text) {
        $!scroll-pos += 1 if $!scroll-pos == @!log;
        @!log.push($text);
    }

    #| Refresh display
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-framing;

        # Print most recent content-height wrapped lines
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $t      = $layout.top-correction;
        my $h      = $.h - $layout.height-correction;
        my $top    = 0 max $.scroll-pos - $h;

        for ^$h {
            my $line = @!log[$top + $_] // '';
            $.grid.set-span-text($x, $t + $_, $line);
        }

        self.composite(:$print);
    }
}
