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
    has UInt:D     $!wrap-width   = 0;
    has %!hard-lines;
    has %!laid-out;

    #| Add content for a single entry (in styled spans or a plain string) to the log
    multi method add-entry(SpanContent $content) {
        self.add-entry(LogEntry.new(:$content))
    }

    #| Add a single LogEntry to the log
    multi method add-entry(LogEntry:D $entry) {
        # Auto-scroll to new entry if needed
        $!scroll-entry++ if $!scroll-entry == @.log.end;
        @!log.push($entry);
    }

    #| Refresh widget display completely
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-frame;
        self.composite(:$print);
    }

    #| Render visible log lines
    method draw-frame() {
        # Draw framing first
        self.draw-framing;

        # Compute available viewer area; bail if empty
        my $layout = self.layout.computed;
        my $w      = 0 max $.w - $layout.width-correction;
        my $h      = 0 max $.h - $layout.height-correction;
        return unless $w && $h;

        # Empty layout cache unless it is still valid for current available width
        unless $!wrap-width == $w {
            $!wrap-width = $w;
            %!laid-out   = Empty;
        }

        # Cache layout for surrounding entries starting from current
        # scroll-entry, stopping if they would overfill the current viewer area

        # Available fully laid out lines surrounding scroll-entry
        my $avail = 0;

        # Current and previous entries first
        my $cur = $!scroll-entry;
        while $avail < $h && $cur >= 0 && (my $entry = @!log[$cur--]) {
            my @lines := %!laid-out{$entry.id} //= self.layout-entry($entry, $w);
            $avail    += @lines;
        }
        $cur = 0 if $cur < 0;

        # Following entries next, if needed
        my $next = $!scroll-entry;
        while $avail < $h && ($entry = @!log[++$next]) {
            my @lines := %!laid-out{$entry.id} //= self.layout-entry($entry, $w);
            $avail    += @lines;
        }

        # Render entries, accounting for scrolling and layout corrections
        my $l = $layout.left-correction;
        my $t = $layout.top-correction;
        my $s = 0 max $avail - $h + 1;
        my $y = 0;
        VIEWER_LINE: while $y < $h {
            my  $entry  = @!log[$cur++] // last;
            my  @lines := %!laid-out{$entry.id};
            for @lines -> @spans {
                next if $s-- > 0;
                my $x = $l;
                for @spans {
                    $.grid.set-span($x, $t + $y, .text, .color);
                    $x += .width;
                }
                last VIEWER_LINE if ++$y >= $h;
            }
        }
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
