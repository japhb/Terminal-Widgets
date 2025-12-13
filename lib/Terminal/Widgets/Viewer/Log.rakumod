# ABSTRACT: Simple auto-scrolling log viewer

use nano;

use Terminal::Widgets::TextContent;
use Terminal::Widgets::Layout;
use Terminal::Widgets::WrappableBuffer;


#| A single log entry, with (unprocessed) content and metadata
my class LogEntry is Terminal::Widgets::LineGroup {
    has $.timestamp = now;
}


#| Simple auto-scrolling log viewer
class Terminal::Widgets::Viewer::Log
 does Terminal::Widgets::WrappableBuffer {
    has UInt:D @!skip-table;
    has UInt:D %!start-line;

    method layout-class() { Terminal::Widgets::Layout::LogViewer }

    #| Add content for a single entry (in styled spans or a plain string) to the log
    multi method add-entry(TextContent:D $content) {
        self.add-entry(LogEntry.new(:$content))
    }

    #| Add a single LogEntry to the log
    multi method add-entry(LogEntry:D $entry) {
        my $t0 = nano;

        # Set start line for entry
        my $start = %!start-line{$entry.id} = $!hard-line-count;

        # Append the new LogEntry and update the skip table
        self.insert-line-group($entry);
        self.update-skip-table;

        # Update scrolling maxes as needed
        self.set-x-max($!hard-line-max-width) if $!hard-line-max-width > $.x-max;
        self.set-y-max($!hard-line-count);

        # Auto-scroll to make room for new entry if previous line visible
        my $ch = self.content-height;
        if $.y-scroll + $ch >= $start {
            self.set-y-scroll($!hard-line-count - $ch);
        }

        note sprintf("⏱️  Log.add-entry: %.3fms",
                     (nano - $t0) / 1_000_000) if $.debug;
    }

    #| Update the skip table with the latest log entry
    method update-skip-table() {
        @!skip-table[$!hard-line-count +> 10] = @!line-groups.elems;
    }

    #| Use the skip table to find a starting point to search for a given line
    method search-skip-table(UInt:D $line-number) {
        my $entry = $line-number +> 10 - 1;

        $entry <  0            ?? 0 !!
        $entry >= @!skip-table ?? @!skip-table[@!skip-table.end] !!
                                  @!skip-table[$entry] // do {
            # Missing skip-table entry, start working back
            while --$entry >= 0 {
                return my $i = @!skip-table[$entry] if $i.defined;
            }
            # Didn't find any valid entry below the expected one, just return 0
            0
        }
    }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my $t0 = nano;

        return [] unless @!line-groups;

        my $i   = self.search-skip-table($start);
        my $pos = %!start-line{@!line-groups[$i].id};
        my @found;

        while $i < @!line-groups {
            my $lines = %!hard-lines{@!line-groups[$i++].id};
            my $prev  = $pos;
            $pos += $lines.elems;
            next if $start >= $pos;

            @found.append($start > $prev ?? @$lines[($start - $prev)..*]
                                         !! @$lines);
            last if @found >= $wanted;
        }

        note sprintf("⏱️  Log.span-line-chunk: %.3fms",
                     (nano - $t0) / 1_000_000) if $.debug;

        @found
    }
}


# Register Viewer::Log as a buildable widget type
Terminal::Widgets::Viewer::Log.register;
