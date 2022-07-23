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
    method refresh-all() {
        self.clear-frame;

        # Print most recent $.h wrapped lines
        my $top = max 0, $.scroll-pos - $.h;

        for ^$.h {
            my $line = @!log[$top + $_] // '';
            $.grid.set-span-text(0, $_, $line);
        }
    }
}
