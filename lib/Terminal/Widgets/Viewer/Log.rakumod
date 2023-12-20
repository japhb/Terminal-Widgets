# ABSTRACT: Simple auto-scrolling log viewer

use Text::MiscUtils::Layout;

use Terminal::Widgets::Widget;
use Terminal::Widgets::SpanStyle;


my atomicint $NEXT-ID = 0;
sub term:<NEXT-ID>() { ++⚛$NEXT-ID }


#| A single log entry, with (unprocessed) content and metadata
my class LogEntry {
    has SpanContent $.content is required;
    has $.timestamp = now;
    has $.id        = NEXT-ID;
}


#| Simple auto-scrolling log viewer
class Terminal::Widgets::Viewer::Log
   is Terminal::Widgets::Widget {
    has LogEntry:D @.log;
    has Int:D      $.scroll-entry = -1;
    has UInt:D     $.scroll-line  = 0;
    has UInt:D     $!wrap-width   = 0;
    has UInt:D     $!total-lines  = 0;
    has %!top-hard-line;
    has %!hard-lines;
    has %!laid-out;

    #| Add content for a single entry (in styled spans or a plain string) to the log
    multi method add-entry(SpanContent $content) {
        self.add-entry(LogEntry.new(:$content))
    }

    #| Add a single LogEntry to the log
    multi method add-entry(LogEntry:D $entry) {
        # Auto-scroll to new entry if needed
        if  $!scroll-entry == @.log.end {
            $!scroll-entry++;
            $!scroll-line = 0;
        }

        my $id = ~$entry.id;
        @!log.push($entry);
        %!top-hard-line{$id} = $!total-lines;

        my $lines      = +(%!hard-lines{$id} = self.hard-lines($entry));
        $!total-lines += $lines;
    }

    #| Refresh display
    method full-refresh(Bool:D :$print = True) {
        # Clear grid and draw framing if any
        self.clear-frame;
        self.draw-framing;

        # Compute available viewer area; bail if empty
        my $layout = self.layout.computed;
        my $w      = 0 max $.w - $layout.width-correction;
        my $h      = 0 max $.h - $layout.height-correction;
        return self.composite(:$print) unless $w && $h;

        # Empty layout cache unless it is still valid for current available width
        %!laid-out = () unless $!wrap-width == $w;

        # Cache layout for previous entries starting from current scroll-entry,
        # stopping if they would overfill the current viewer area
        my $avail  = 0;
        my $cur    = $!scroll-entry;

        while $cur >= 0 && $avail < $h {
            my $entry  = @!log[$cur];
            my @lines := %!laid-out{$entry.id} //= self.layout-entry($entry, $w);
            $avail    += @lines;
            $cur--;
        }
        $cur = 0 if $cur < 0;

        # Render entries, accounting for scrolling and layout corrections
        my $l = $layout.left-correction;
        my $t = $layout.top-correction;
        my $y = 0;
        VIEWER_LINE: while $y < $h {
            my  $entry  = @!log[$cur++] // last;
            my  @lines := %!laid-out{$entry.id} //= self.layout-entry($entry, $w);
            for @lines -> @spans {
                my $x = $l;
                for @spans {
                    $.grid.set-span($x, $t + $y, .text, .color);
                    $x += duospace-width(.text);
                }
                last VIEWER_LINE if ++$y >= $h;
            }
        }

        # Composite result
        self.composite(:$print);
    }

    #| Lay out an individual entry for a particular viewer width
    method layout-entry(LogEntry:D $entry, UInt:D $width) {
        my $id    = ~$entry.id;
        my @hard := %!hard-lines{$id} //= self.hard-lines($entry);

        # XXXX: Just return the hard lines with no further changes
        @hard
    }

    #| Compute the list of hard lines for a particular LogEntry
    method hard-lines(LogEntry:D $entry) {
        my $as-tree = $entry.content ~~ Terminal::Widgets::SpanStyle::SpanTree
                        ?? $entry.content
                        !! span-tree('', $entry.content);
        $as-tree.lines.eager
    }
}
