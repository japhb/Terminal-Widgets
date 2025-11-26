# ABSTRACT: Simple auto-scrolling log viewer

use Terminal::Widgets::SpanStyle Empty;
use Terminal::Widgets::TextContent;
use Terminal::Widgets::SpanBuffer;


my atomicint $NEXT-ID = 0;
sub term:<NEXT-ID>() { ++⚛$NEXT-ID }

subset Content where TextContent | Terminal::Widgets::SpanStyle::SpanContent;

#| A single log entry, with (unprocessed) content and metadata
my class LogEntry {
    has Content:D   $.content is required;
    has $.timestamp = now;
    has $.id        = NEXT-ID;
}


#| Simple auto-scrolling log viewer
class Terminal::Widgets::Viewer::Log
 does Terminal::Widgets::SpanBuffer {
    has LogEntry:D @.log;
    has UInt:D     $!next-start = 0;
    has UInt:D     %!start-line;
    has            %!hard-lines;

    #| Add content for a single entry (in styled spans or a plain string) to the log
    multi method add-entry(Content $content) {
        self.add-entry(LogEntry.new(:$content))
    }

    #| Add a single LogEntry to the log
    multi method add-entry(LogEntry:D $entry) {
        # Cache hard line info about this LogEntry
        my $id    = ~$entry.id;
        my $lines = %!hard-lines{$id} = self.hard-lines($entry);

        # Widen horizontal scrolling if new lines are longer
        my $widest = $lines.map(*.map(*.width).sum).max;
        self.set-x-max($widest) if $widest > $.x-max;

        # Update for next start line
        my $after = $!next-start + $lines.elems;
        %!start-line{$id} = $!next-start;
        self.set-y-max($after);

        # Auto-scroll to make room for new entry if previous line visible
        my $ch = self.content-height;
        if $.y-scroll + $ch >= $!next-start {
            self.set-y-scroll($after - $ch);
        }
        $!next-start = $after;

        # Finally, push new LogEntry to log history
        @!log.push($entry);
    }

    #| Compute the list of hard lines for a particular LogEntry
    method hard-lines(LogEntry:D $entry) {
        constant SS = Terminal::Widgets::SpanStyle;
        constant TC = Terminal::Widgets::TextContent;

        my $as-tree = do given $entry.content {
            when SS::Span       { SS::span-tree('', [$_]) }
            when SS::SpanTree   { $_ }

            when Str            { TC::span-tree($_) }
            when TC::StringSpan { TC::span-tree($_) }
            when TC::SpanTree   { $_ }

            default { die "Unrecognized LogEntry.content type {.^name.raku}" }
        };

        $as-tree ~~ TC::SpanTree
        ?? $as-tree.lines.map(*.map(*.render).eager).eager
        !! $as-tree.lines.eager;
    }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my $pos = 0;
        my @found;

        for @.log {
            my $lines = %!hard-lines{.id};
            my $prev  = $pos;
            $pos += $lines.elems;
            next if $start >= $pos;

            @found.append($start > $prev ?? @$lines[($start - $prev)..*]
                                         !! @$lines);
            last if @found >= $wanted;
        }

        @found
    }
}
