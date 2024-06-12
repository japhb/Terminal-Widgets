# ABSTRACT: A text widget that has clickable lines / a selected line.

use Text::MiscUtils::Layout;

use Terminal::Widgets::Events;
use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::Focusable;

enum WrapStyle <NoWrap LineWrap WordWrap>;

class Terminal::Widgets::RichText
 does Terminal::Widgets::SpanBuffer
 does Terminal::Widgets::Focusable {
    has @.lines;
    #| For each line, in which display line does it start?
    has @!l-dl;
    #| For each diplay line, which line is there?
    has @!dl-l;
    has $!widest;
    has $!first-display-line = 0;

    has $.wrap = NoWrap;
    has Bool $.highlight-line = False;
    has Bool $.show-cursor = False;
    has $.cursor-x = 0;
    has $.cursor-y = 0;

    has &.process-click;

    submethod TWEAK() {
        self.init-focusable;
    }

    method set-wrap(WrapStyle $wrap) {
        $!wrap = $wrap;
        self!my-refresh;
    }

    method set-show-cursor(Bool $show-cursor) {
        $!show-cursor = $show-cursor;
        self.full-refresh;
    }

    method set-highlight-line(Bool $highlight) {
        $!highlight-line = $highlight;
        self.full-refresh;
    }

    #| Add content for a single entry (in styled spans or a plain string) to the log
    method set-text(SpanContent $content) {
        my $as-tree = $content ~~ Terminal::Widgets::SpanStyle::SpanTree
                        ?? $content
                        !! span-tree('', $content);
        @!lines = $as-tree.lines.eager;
        self!calc-widest;
        self!my-refresh;
    }

    method splice-lines($from, $count, $replacement) {
        my $as-tree = $replacement ~~ Terminal::Widgets::SpanStyle::SpanTree
                        ?? $replacement
                        !! span-tree('', $replacement);
        my @repl-lines = $as-tree.lines.eager;
        @!lines.splice: $from, $count, @repl-lines;

        self!calc-widest;
        self!my-refresh($from);
    }


    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        sub add-cursor(@line, $pos is copy) {
            $pos = min $pos, self!chars-in-line(@line) - 1;
            my @new-line;
            my $x = 0;
            for @line -> $span is copy {
                my $chars = $span.text.chars;
                if $x <= $pos < $x + $chars {
                    if $pos - $x > 0 {
                        @new-line.push: span($span.color, $span.text.substr(0, $pos - $x));
                    }
                    @new-line.push: span-tree(
                        self.current-color(%( |self.current-color-states, :cursor)),
                        span($span.color, $span.text.substr($pos - $x, 1))).lines.eager[0][0];
                    if $pos - $x + 1 < $chars {
                        @new-line.push: span($span.color, $span.text.substr($pos - $x + 1));
                    }
                }
                else {
                    $x += $chars;
                    @new-line.push: $span;
                }
            }
            @new-line
        }

        sub line($i) {
            if $i == $!cursor-y {
                my @line = span-tree(self.current-color(%( |self.current-color-states, :prompt )), @!lines[$i]).lines.eager[0];
                if $!show-cursor {
                    @line = add-cursor @line, $!cursor-x;
                }
                @line
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
        my @result = self!wrap(line($line-index++))[$start-offset..*];

        while @result.elems < $wanted && $line-index < @!lines.elems {
            @result.append(self!wrap(line($line-index++)));
        }
        @result
    }

    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorDown  => 'select-next-line',
            CursorUp    => 'select-prev-line',
            CursorLeft  => 'select-prev-char',
            CursorRight => 'select-next-char',
            Ctrl-I      => 'next-input',    # Tab
            ShiftTab    => 'prev-input',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'select-next-line' { self.select-line($!cursor-y + 1) }
            when 'select-prev-line' { self.select-line($!cursor-y - 1) }
            when 'select-next-char' { self.next-char }
            when 'select-prev-char' { self.prev-char }
            when 'next-input'  { self.focus-next-input }
            when 'prev-input'  { self.focus-prev-input }
        }
    }

    method select-line($no is copy) {
        $no = max($no, 0);
        $no = min($no, @!lines.end);
        $!cursor-y = $no;
        self.ensure-y-span-visible(@!l-dl[$!cursor-y], @!l-dl[$!cursor-y] + self!height-of-line(@!lines[$no]) - 1);
        self.full-refresh;
    }

    method prev-char() {
        my $pos;
        if $!cursor-x == 0 {
            if $!cursor-y > 0 {
                $!cursor-y--;
                $pos = self!chars-in-line(@!lines[$!cursor-y]) - 1;
            }
        }
        else {
            my $max = self!chars-in-line(@!lines[$!cursor-y]) - 1;
            if $!cursor-x > $max {
                $pos = $max;
            }
            $pos = $!cursor-x - 1;
        }
        self.select-char($pos);
    }

    method next-char() {
        my $pos;
        my $max = self!chars-in-line(@!lines[$!cursor-y]) - 1;
        if $!cursor-x >= $max {
            if $!cursor-y < @!lines - 1 {
                $!cursor-y++;
                $pos = 0;
            }
        }
        else {
            $pos = $!cursor-x + 1;
        }
        self.select-char($pos);
    }

    method select-char($no is copy) {
        $no = max($no, 0);
        $no = min($no, self!chars-in-line(@!lines[$!cursor-y]) - 1);
        $!cursor-x = $no;
        if $!wrap ~~ NoWrap {
            my ($upto, $cursor) = self!width-up-to-pos(@!lines[$!cursor-y], $!cursor-x);
            self.ensure-x-span-visible($upto, $upto);
        }
        self.full-refresh;
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        self.toplevel.focus-on(self);

        my ($x, $y) = $event.relative-to(self);
        my $clicked-display-line = $!first-display-line + $y;
        my $line-index = @!dl-l[min($clicked-display-line, @!dl-l.end)];
        $!cursor-y = $line-index;
        my $rel-y = $y - @!l-dl[$line-index];
        $x = self!display-pos-to-line-pos(@!lines[$line-index], self.x-scroll + $x, $rel-y);
        $!cursor-x = min(self!chars-in-line(@!lines[$line-index]) - 1, $x);
        self.full-refresh;
        &!process-click($line-index, $x, 0) with &!process-click;
    }

    method !my-refresh($from = 0) {
        my $first-line = 0;
        my $sub-line = 0;
        if @!dl-l {
            $first-line = @!dl-l[$!first-display-line];
            $sub-line = $!first-display-line - @!l-dl[$first-line];
        }
        if $!wrap ~~ NoWrap {
            self.set-x-max($!widest) if $!widest > $.x-max;
        }
        else {
            self.set-x-max(self.content-width);
            self.set-x-scroll(0);
        }
        self!calc-indexes($from);
        self.set-y-max(@!dl-l.end);
        my $new-first-line-start = @!l-dl[$first-line];
        my $new-first-line-height = self!height-of-line(@!lines[$first-line]);
        self.set-y-scroll($new-first-line-start + min($sub-line, $new-first-line-height));
        self.full-refresh;
        self.refresh-for-scroll;
    }

    method !calc-indexes($from = 0) {
        my $dpos = @!l-dl[$from] // 0;
        loop (my $pos = $from; $pos < @!lines.elems; $pos++) {
            my $l = @!lines[$pos];
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

    method !wrap(@line) {
        given $!wrap {
            when NoWrap { 
                [@line,]
            }
            when LineWrap {
                self!line-wrap: @line, self.content-width
            }
            when WordWrap {
                self!word-wrap: @line, self.content-width
            }
        }
    }

    method !line-wrap(@line, $width) {
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
                                self!chars-fitting-in-width($span.text, $remaining-space));
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

    method !word-wrap(@line, $width) {
        my $text = self!spans-to-text(@line);
        my @positions;
        my @candidates = $text ~~ m:g/ << /;
        @candidates .= map: *.from;
        my $pos = 0;
        my $rest-width = $width;

        while $pos < $text.chars {
            my $fitting = $pos + self!chars-fitting-in-width($text.substr($pos), $width);
            my $cut;
            $cut = @candidates.shift while @candidates && @candidates[0] <= $fitting;
            if $cut {
                @positions.push: $cut;
                $pos = $cut;
            }
            else {
                # No clean cut fits into the line.
                @positions.push: $fitting;
                $pos = $fitting;
            }
        }

        self!split-spans-at-positions: @line, @positions;
    }

    method !display-pos-to-line-pos(@line, $x, $y) {
        my @sub-lines = self!wrap(@line);
        my $pos = [+] @sub-lines[^$y].map({ self!chars-in-line($_) });
        $pos + self!chars-fitting-in-width(self!spans-to-text(@sub-lines[$y]), $x)
    }

    method !height-of-line(@line) {
        self!wrap(@line).elems
    }

    method !chars-in-line(@line) {
        @line.map(*.text.chars).sum
    }

    method !chars-fitting-in-width($text, $width --> Int) {
        my $count = $width;
        while duospace-width($text.substr(0, $count)) > $width {
            $count--;
        }
        $count
    }

    method !spans-to-text(@spans --> Str) {
        [~] @spans.map(*.text)
    }

    method !split-spans-at-positions(@spans, @positions is copy) {
        @positions .= sort;
        my @result;
        my @next;
        my $len = 0;
        for @spans -> $span is copy {
            if @positions {
                loop {
                    my $chars = $span.text.chars;
                    if $len + $chars < @positions[0] {
                        $len += $chars;
                        @next.push: $span;
                        last;
                    }
                    elsif $len + $chars == @positions[0] {
                        $len += $chars;
                        @next.push: $span;
                        @result.push: @next;
                        @next := [];
                        @positions.shift;
                        last;
                    }
                    else {
                        my $remaining-chars = @positions[0] - $len;
                        $len += $remaining-chars;
                        my $first = $span.text.substr(0, $remaining-chars);
                        my $second = $span.text.substr($remaining-chars);
                        @next.push: span($span.color, $first);
                        @result.push: @next;
                        @next := [];
                        @positions.shift;
                        $span = span($span.color, $second);
                    }
                }
            }
            else {
                @next.push: $span;
            }
        }
        @result.push: @next if @next;
        @result
    }

    method !width-up-to-pos(@line, $pos is copy) {
        $pos = min $pos, self!chars-in-line(@line) - 1;
        my $width = 0;
        my $x = 0;
        for @line -> $span is copy {
            my $chars = $span.text.chars;
            if $pos <= $x + $chars {
                return ($width + span($span.color, $span.text.substr(0, $pos - $x)).width, span($span.color, $span.text.substr($pos - $x, 1)).width);
            }
            else {
                $x += $chars;
                $width += $span.width;
            }
        }
    }
    
    sub log($t) {
        "o".IO.spurt: $t ~ "\n", :append;
    }
}
