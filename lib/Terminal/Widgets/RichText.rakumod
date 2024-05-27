# ABSTRACT: A text widget that has clickable lines / a selected line.

use Text::MiscUtils::Layout;

use Terminal::Widgets::Events;
use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::Focusable;

#| Simple auto-scrolling log viewer
class Terminal::Widgets::RichText
 does Terminal::Widgets::SpanBuffer
 does Terminal::Widgets::Focusable {
    has @.lines;
    #| For each line, in which display line does it start?
    has @!l-dl;
    #| For each diplay line, which line is there?
    has @!dl-l;
    has $.wrap = False;
    has $!widest;
    has $!first-display-line = 0;
    has &.process-click;
    has $.selected-line = 0;
    has $.selected-line-style is built = 'bold white on_blue';

    submethod TWEAK() {
        self.init-focusable;
    }

    method set-wrap($wrap) {
        $!wrap = $wrap;
        self.my-refresh;
    }

    method my-refresh() {
        my $first-line = 0;
        my $sub-line = 0;
        if @!dl-l {
            $first-line = @!dl-l[$!first-display-line];
            $sub-line = $!first-display-line - @!l-dl[$first-line];
        }
        if !$!wrap {
            self.set-x-max($!widest) if $!widest > $.x-max;
        }
        else {
            self.set-x-max(self.content-width);
            self.set-x-scroll(0);
        }
        self!calc-indexes;
        self.set-y-max(@!dl-l.end);
        my $new-first-line-start = @!l-dl[$first-line];
        my $new-first-line-height = self!height-of-line(@!lines[$first-line]);
        self.set-y-scroll($new-first-line-start + min($sub-line, $new-first-line-height));
        self.full-refresh;
        self.refresh-for-scroll;
    }

    method !calc-indexes() {
        my $dpos = 0;
        for @!lines.kv -> $pos, $l {
            @!l-dl[$pos] = $dpos;
            my $line-height = self!height-of-line($l);
            @!dl-l[$dpos++] = $pos for ^$line-height;
        }
        @!l-dl.splice: @!lines.elems;
        @!dl-l.splice: $dpos;
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
        self!calc-widest;
        self.my-refresh;
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
                        my $first = $span.text.substr(0,
                                    self!count-fitting-in-width($span.text, $remaining-space));
                        my $second = $span.text.substr($first.chars);
                        @next.push: span($span.color, $first);
                        @wrapped.push: @next;
                        @next := [];
                        $len = 0;
                        $span = span($span.color, $second);
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

    method !display-pos-to-line-pos(@line, $x, $y) {
        my $width = self.content-width;
        my $lx = 0;
        my $rx = 0;
        my $ry = 0;
        for @line -> $span is copy {
            loop {
                if $ry < $y {
                    if $rx + $span.width < $width {
                        $rx += $span.width;
                        last;
                    }
                    elsif $rx + $span.width == $width {
                        $lx += $rx + $span.width;
                        $rx = 0;
                        $ry++;
                        last;
                    }
                    else {
                        my $remaining-space = $width - $rx;
                        my $fitting = self!count-fitting-in-width($span.text, $remaining-space);
                        $span = span($span.color, $span.text.substr($fitting));
                        $lx += $rx + $fitting;
                        $rx = 0;
                        $ry++;
                    }
                }
                else {
                    if $rx + $span.width < $x {
                        $rx += $span.width;
                        last;
                    }
                    elsif $rx + $span.width == $x {
                        return ($lx + $rx + $span.width, 0);
                    }
                    else {
                        my $remaining-space = $x - $rx;
                        return ($lx + $rx + self!count-fitting-in-width($span.text, $remaining-space), 0);
                    }
                }
            }
        }
    }

    method !count-fitting-in-width($text, $width --> Int) {
        my $count = $width;
        while duospace-width($text.substr(0, $count)) > $width {
            $count--;
        }
        $count
    }

    method !height-of-line(@line) {
        self!wrap-line(@line).elems
    }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        sub line($i) {
            if $i == $!selected-line {
                span-tree(self.current-color(%( |self.current-color-states, :prompt )), @!lines[$i]).lines.eager[0]
            }
            else {
                @!lines[$i]
            }
        }
        $!first-display-line = $start;
        my $pos = 0;
        my $line-index = @!dl-l[$start];
        my $line-display-line = @!l-dl[$line-index];

        my $start-offset = $start - $line-display-line;
        my @result = self!wrap-line(line($line-index++))[$start-offset..*];

        while @result.elems < $wanted && $line-index < @!lines.elems {
            @result.append(self!wrap-line(line($line-index++)));
        }

        @result
    }

    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorDown => 'select-next',
            CursorUp   => 'select-prev',
            Ctrl-I     => 'next-input',    # Tab
            ShiftTab   => 'prev-input',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'select-next' { self.select-line($!selected-line + 1) }
            when 'select-prev' { self.select-line($!selected-line - 1) }
            when 'next-input'  { self.focus-next-input }
            when 'prev-input'  { self.focus-prev-input }
        }
    }

    method select-line($no is copy) {
        $no = max($no, 0);
        $no = min($no, @!lines.end);
        $!selected-line = $no;
        self.ensure-y-span-visible(@!l-dl[$!selected-line], @!l-dl[$!selected-line] + self!height-of-line(@!lines[$no]) - 1);
        self.full-refresh;
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        self.toplevel.focus-on(self);

        my ($x, $y) = $event.relative-to(self);
        my $clicked-display-line = $!first-display-line + $y;
        my $line-index = @!dl-l[min($clicked-display-line, @!dl-l.end)];
        if $!selected-line != $line-index {
            $!selected-line = $line-index;
            self.full-refresh;
        }
        my $rel-y = $y - @!l-dl[$line-index];
        ($x, $y) = self!display-pos-to-line-pos(@!lines[$line-index], self.x-scroll + $x, $rel-y);
        &!process-click($line-index, $x, $y) with &!process-click;
    }
}
