# ABSTRACT: A text widget that has clickable lines / a selected line.

use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::SpanBuffer;

#| Simple auto-scrolling log viewer
class Terminal::Widgets::RichText
 does Terminal::Widgets::SpanBuffer {
    has @.lines;
    #| For each line, in which display line does it start?
    has @.line-starts;
    #| For each diplay line, which line is there?
    has @!display-lines;
    has $.wrap = False;
    has $!widest;

    method set-wrap($wrap) {
        $!wrap = $wrap;
        self!my-refresh;
    }

    method !my-refresh() {
        if !$!wrap {
            self.set-x-max($!widest) if $!widest > $.x-max;
        }
        else {
            self.set-x-max(self.content-width);
            self.set-x-scroll(0);
        }
        self!calc-indexes;
        self.set-y-max(@!display-lines.end);
        self.full-refresh;
        self.refresh-for-scroll;
    }

    method !calc-indexes() {
        my $dpos = 0;
        for @!lines.kv -> $pos, $l {
            @!line-starts[$pos] = $dpos;
            my $line-height = 1;
            @!display-lines[$dpos++] = $pos for ^$line-height;
        }
        @!line-starts.splice: @!lines.elems;
        @!display-lines.splice: $dpos;
    }

    method !calc-widest() {
        $!widest = @!lines.map(*.map(*.width).sum).max;
    }

    #| Add content for a single entry (in styled spans or a plain string) to the log
    method set-text(SpanContent $content) {
        my $as-tree = $content ~~ Terminal::Widgets::SpanStyle::SpanTree
                        ?? $content
                        !! span-tree('', $content);
        @!lines = $as-tree.lines.eager;
        self!calc-indexes;
        self!calc-widest;
        self!my-refresh;
    }

    method !wrap-line(@line) {
        if $!wrap {
            my $width = self.content-width;
            my @wrapped;
            my @next;
            my $len = 0;
            for @line -> $span is copy {
                loop {
                    if $len + $span.width < $width {
                        $len += $span.width;
                        @next.push: $span;
                        last;
                    }
                    elsif $len + $span.width == $width {
                        @next.push: $span;
                        @wrapped.push: @next;
                        @next := [];
                        $len = 0;
                        last;
                    }
                    else {
                        my $remaining-space = $width - $len;
                        #TODO: Deal with duowidth chars!
                        @next.push: span($span.color, $span.text.substr(0, $remaining-space));
                        @wrapped.push: @next;
                        @next := [];
                        $len = 0;
                        $span = span($span.color, $span.text.substr($remaining-space));
                    }
                }
            }
            @wrapped.push: @next if @next;
            @wrapped
        }
        else {
            [@line,]
        }
    }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my $pos = 0;
        my $line-index = @!display-lines[$start];
        my $line-display-line = @!line-starts[$start];

        my $start-offset = $start - $line-display-line;
        my @result = self!wrap-line(@!lines[$line-index++])[$start-offset..*];

        while @result.elems < $wanted && $line-index < @!lines.elems {
            @result.append(self!wrap-line(@!lines[$line-index++]));
        }

        @result
    }
}
