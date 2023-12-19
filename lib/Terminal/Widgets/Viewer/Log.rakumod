# ABSTRACT: Simple auto-scrolling log viewer

use Text::MiscUtils::Layout;

use Terminal::Widgets::Widget;
use Terminal::Widgets::SpanStyle;


my class LogEntry {
    has SpanContent $.content is required;
    has $.timestamp = now;
    has @.hard-lines is built(False);

    submethod TWEAK() {
        my $as-tree  = $!content ~~ Terminal::Widgets::SpanStyle::SpanTree
                         ?? $!content
                         !! span-tree('', $!content);
        @!hard-lines = $as-tree.lines;
    }
}


#| Simple auto-scrolling log viewer
class Terminal::Widgets::Viewer::Log
   is Terminal::Widgets::Widget {
    has UInt:D $.scroll-pos = 0;
    has @.log;

    #| Add content for a single entry (in styled spans or a plain string) to the log
    multi method add-entry(SpanContent $content) {
        self.add-entry(LogEntry.new(:$content))
    }

    #| Add a single LogEntry to the log
    multi method add-entry(LogEntry:D $entry) {
        $!scroll-pos += 1 if $!scroll-pos == @!log;
        @!log.push($entry);
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

        my $y = $t;
        for ^$h {
            my  $entry = @!log[$top + $_] // LogEntry.new(content => '');
            for $entry.hard-lines -> @spans {
                my $x = $l;
                for @spans {
                    $.grid.set-span($x, $y, .text, .color);
                    $x += duospace-width(.text);
                }
                $y++;
            }
        }

        self.composite(:$print);
    }
}
