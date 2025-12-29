# ABSTRACT: SpanBuffer extension allowing line wrapping and fills

use nano;

use Text::MiscUtils::Layout;

use Terminal::Widgets::Terminal;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::TextContent;

constant TC = Terminal::Widgets::TextContent;


# Unique LineGroup ID generator
my atomicint $NEXT-ID = 0;
sub term:<NEXT-ID>() { ++⚛$NEXT-ID }

#| A group of lines that will wrap or fill together,
#| such as a paragraph, log entry, or value list
class Terminal::Widgets::LineGroup {
    has TextContent:D $.content is required;
    has               $.id = NEXT-ID;
}


#| Available text wrapping/filling modes; each works *within* a LineGroup.
#| *Wrap variants can only split lines; *Fill variants can merge them as well.
enum Terminal::Widgets::WrapMode is export
    < NoWrap GraphemeWrap WordWrap GraphemeFill WordFill >;

#| Handling of whitespace when wrapping/filling within a LineGroup.
#| Partial replaces whitespace runs inside a span with a single space.
#| Full additionally removes leading whitespace at start of line and
#| squashes whitespace that crosses span boundaries to a single space.
enum Terminal::Widgets::WhitespaceSquashMode is export
    < NoSquash PartialSquash FullSquash >;

#| Style selection for wrapping/filling modes
class Terminal::Widgets::WrapStyle {
    has Terminal::Widgets::Terminal:D $.terminal is required;

    has Terminal::Widgets::WrapMode:D             $.wrap-mode   = NoWrap;
    has Terminal::Widgets::WhitespaceSquashMode:D $.squash-mode = NoSquash;

    has TextContent:D $.wrapped-line-prefix = '';

    has @.rendered-prefix is built(False);
    has $.prefix-length   is built(False);

    # Ensure render-prefix is called on any new or clone
    submethod TWEAK {  self.render-prefix }
    method clone { callsame.render-prefix }

    method render-prefix() {
        my $renderer      = $!terminal.locale.renderer;
        @!rendered-prefix = $renderer.render($!wrapped-line-prefix);
        $!prefix-length   = @!rendered-prefix.map(*.width).sum;

        self
    }
}


#| A SpanBuffer extension handling line wraps and fills
role Terminal::Widgets::WrappableBuffer
does Terminal::Widgets::SpanBuffer {
    has Terminal::Widgets::LineGroup:D @.line-groups;
    has Terminal::Widgets::WrapStyle:D $.wrap-style .= new(terminal => self.terminal);

    has UInt:D $!hard-line-max-width = 0;
    has UInt:D $!hard-line-count     = 0;
    has UInt:D %!hard-line-width;
    has        %!hard-lines;

    has UInt:D $!wrap-width = self.content-width;
    has        %!wrapped-lines;

    #| Set wrap-style, then clear wrap caches and fix horizontal scroll width
    method set-wrap-style(Terminal::Widgets::WrapStyle:D $new-style) {
        if  $!wrap-style !=== $new-style {
            $!wrap-style    = $new-style;
            %!wrapped-lines = Empty;

            my $wrapping = $!wrap-style.wrap-mode != NoWrap;
            self.set-x-max($wrapping ?? $!wrap-width !! $!hard-line-max-width);
        }
    }

    #| Check that wrap width has not changed; otherwise, clear wrap caches
    method check-wrap-width() {
        my $width  = self.content-width;
        if $width != $!wrap-width {
            $!wrap-width    = $width;
            %!wrapped-lines = Empty;
        }
    }

    #| Update scrolling maxes as needed
    method update-scroll-maxes() {
        if $.wrap-style.wrap-mode == NoWrap {
            self.set-x-max($!hard-line-max-width) if $!hard-line-max-width > $.x-max;
            self.set-y-max($!hard-line-count);
        }
        else {
            # Fixup x-max, possibly clearing wrapped-lines cache if needed
            self.check-wrap-width;
            self.set-x-max($!wrap-width);

            # Make sure all LineGroups have wrapped lines cached,
            # then set y-max equal to total of all wrapped lines
            %!wrapped-lines{.id} //= self.wrap-lines(.id) for @!line-groups;
            self.set-y-max(%!wrapped-lines.values.map(*.elems).sum);
        }
    }

    #| Determine if buffer is completely empty
    method empty() { !@!line-groups }

    #| Insert a group of lines (as some TextContent variant) into the buffer
    #| at a given $pos, defaulting to appending at the end
    multi method insert-line-group(TextContent:D $content,
                                   UInt:D $pos = @!line-groups.elems) {
        self.insert-line-group(Terminal::Widgets::LineGroup.new(:$content), $pos)
    }

    #| Insert a single LineGroup into the buffer at a given $pos, defaulting
    #| to appending at the end
    multi method insert-line-group(Terminal::Widgets::LineGroup:D $line-group,
                                   UInt:D $pos = @!line-groups.elems) {
        my $t0 = nano;

        # Make sure this LineGroup hasn't already been added
        my $id = $line-group.id;
        die "LineGroup id #$id already exists in this self.gist-name()"
            if %!hard-lines{$id}:exists;

        # Split content into hard lines and cache result
        my $lines = %!hard-lines{$id} = self.hard-lines($line-group.content);

        # Update total hard line count and max hard line width
        my $widest = $lines.map(*.map(*.width).sum).max;
        %!hard-line-width{$id} = $widest;
        $!hard-line-max-width  = $widest if $widest > $!hard-line-max-width;
        $!hard-line-count     += $lines.elems;

        # Actually splice line group into buffer
        @!line-groups.splice($pos, 0, $line-group);

        self.debug-elapsed($t0);
    }

    #| Split arbitrary TextContent into an array of lines, each of which is
    #| an array of RenderSpans representing a single unwrapped line
    method hard-lines(TextContent:D $content) {
        my $as-tree = $content ~~ TC::SpanTree ?? $content !! TC::span-tree($content);

        $as-tree.lines.map(*.map(*.render).eager).eager
    }

    #| Remove a LineGroup from the buffer and update caches appropriately
    multi method remove-line-group(Terminal::Widgets::LineGroup:D $line-group) {
        self.remove-line-group($line-group.id)
    }

    #| Remove a LineGroup by id and update caches appropriately
    multi method remove-line-group(UInt:D $id) {
        # Find location of LineGroup with this $id within buffer
        my $pos = @!line-groups.grep(*.id == $id, :k) //
            die "LineGroup id #$id does not exist in this self.gist-name()";

        # Remove LineGroup from buffer, reduce hard-line-count, and delete
        # hard-lines/wrapped-lines cache entries
        @!line-groups.splice($pos, 1);
        $!hard-line-count -= %!hard-lines{$id}.elems;
        %!hard-lines{$id}:delete;
        %!wrapped-lines{$id}:delete;

        # Update hard-line-max-width if this entry was the widest
        my $hl-width = %!hard-line-width{$id}:delete;
        $!hard-line-max-width = %!hard-line-width.values.max // 0
            if $hl-width == $!hard-line-max-width;
    }

    #| Wrap or fill hard lines for a given LineGroup id
    #| into wrapped lines as per $!wrap-style.wrap-mode
    method wrap-lines(UInt:D $id) {
        my $hard      = %!hard-lines{$id};
        my $mode      = $!wrap-style.wrap-mode;
        my $squash    = $!wrap-style.squash-mode;
        my $word-mode = $mode == WordWrap | WordFill;

        # Quick exit: Not filling, not needing to squash whitespace, and
        #             wrap-width is wide enough so that normal wrapping
        #             won't affect this LineGroup
        return $hard if $mode == NoWrap
                     || $squash == NoSquash
                        && ($mode == GraphemeWrap | WordWrap)
                        && $!wrap-width >= %!hard-line-width{$id};

        # Determine prefix to use for second and later wrapped lines
        my @prefix     := $!wrap-style.rendered-prefix;
        my $prefix-len  = $!wrap-style.prefix-length;
        if $prefix-len >= $!wrap-width {
            # Wrapped line prefix would fill entire wrap-width by itself;
            # fall back to ignoring prefix to fit actual content instead
            @prefix    := [];
            $prefix-len = 0;
        }
        my $max-wrapped = $!wrap-width - $prefix-len;

        # Wrapping state
        my @wrapped;                #= Fully wrapped lines
        my @partial;                #= Current partial line
        my $pos = 0;                #= Horizontal position within current line
        my $just-finished = False;  #= Just finished a line; only prefix in current
        my $after-ws      = True;   #= Previous segment was whitespace (or start of line)

        # Split a string into alternating whitespace/non-whitespace runs;
        # first whitespace and last non-whitespace runs MAY be empty strings.
        my sub string-runs($string) {
            # This needs to be AFAP, so into NQP land it goes
            use nqp;

            my str $str   = $string;
            my int $chars = nqp::chars($str);
            my int $pos   = 0;
            my int $next  = 0;
            my int $WS    = nqp::const::CCLASS_WHITESPACE;
            my     $runs := nqp::list();

            while $pos < $chars {
                # XXXX: Handle non-breaking spaces

                # Look for end of whitespace and add a run for it
                $next = nqp::findnotcclass($WS, $str, $pos, $chars);
                nqp::push($runs, nqp::substr($str, $pos, $next - $pos));

                # Look for end of NON-whitespace and add a run for it
                $pos = nqp::findcclass($WS, $str, $next, $chars);
                nqp::push($runs, nqp::substr($str, $next, $pos - $next));
            }

            nqp::hllize($runs)
        }

        # Helper sub to finish a line and start a new one
        my sub finish-line($span?) {
            @partial.push($span) if $span;
            @wrapped.push(@partial);

            if @prefix {
                @partial := @prefix.clone;
                $pos      = $prefix-len;
            }
            else {
                @partial := [];
                $pos      = 0;
            }

            $just-finished = True;
            $after-ws      = True;
        }

        # Helper sub to add to a partial line and move $pos
        my sub add-to-partial($span, $width) {
            $just-finished = False;
            @partial.push($span);
            $pos += $width;
        }

        # Core span loop
        my sub span-loop($line) {
            for @$line -> $span {
                # Try to fit span within current partial line
                my $width = $span.width;
                my $next  = $pos + $width;

                # Not squashing and span fits?  Add it in and continue,
                # accounting for any trailing whitespace.
                # This is the FAST PATH for a span.
                if $squash == NoSquash && $next <= $!wrap-width {
                    if $next == $!wrap-width {
                        finish-line($span);
                    }
                    else {
                        add-to-partial($span, $width);
                        $after-ws = ?$span.text.trailing-whitespace;
                    }
                }
                # Squashing and/or need to split span at line end;
                # switch to ws/non-ws runs mode (SLOW PATH).
                else {
                    # Cache for creating span pieces (can't just clone
                    # because RenderSpan has lazily-updated private attrs)
                    my $text        = $span.text;
                    my $color       = $span.color;
                    my $string-span = $span.string-span;

                    # Check whether span is *entirely* monospace, to avoid
                    # having to check for every piece
                    my $all-mono    = $width == $text.chars
                                   && is-monospace-core($text, 0);

                    my  @runs := string-runs($text);
                    for @runs -> $ws, $nws {
                        # First half: Whitespace run
                        if $ws {
                            # XXXX: Handle zero-width, ideographic, and joining spaces

                            # Squash modes: NoSquash, PartialSquash, FullSquash
                            if $squash == NoSquash {
                                my $avail = $!wrap-width - $pos;
                                my $width = $all-mono
                                             ?? $ws.chars
                                             !! duospace-width-core($ws, 0);

                                # Run fits, add it
                                if $width <= $avail {
                                    my $piece = $span.new(:$string-span, :$color,
                                                          text => $ws);
                                    $width < $avail ?? add-to-partial($piece, $width)
                                                    !! finish-line($piece);
                                }
                                # Need to split a run of spaces across lines
                                else {
                                    # Work through the whitespace, chopping off
                                    # pieces that finish lines (last line may be
                                    # partial)
                                    my $remainder = $ws;
                                    while $remainder {
                                        # There's only one Unicode whitespace char
                                        # with width > 1: U+3000 IDEOGRAPHIC SPACE
                                        # All the rest are 0 or 1.
                                        my $avail = $!wrap-width - $pos;
                                        my $chars = !$all-mono
                                                 && $remainder.contains("\x3000")
                                                 ?? $avail div 2 !! $avail;
                                        my $first = $remainder.substr(0, $chars);
                                           $width = $all-mono
                                                    ?? $first.chars
                                                    !! duospace-width-core($first, 0);

                                        # XXXX: Adjust chars/first/width for
                                        #       mixed-width spaces

                                        my $piece = $span.new(:$string-span, :$color,
                                                              text => $first);
                                        $width < $avail
                                            ?? add-to-partial($piece, $width)
                                            !! finish-line($piece);

                                        $after-ws  = True;
                                        my $split  = $chars min $first.chars;
                                        $remainder = $remainder.substr($split);
                                    }
                                }
                            }
                            elsif $squash == PartialSquash || !$after-ws {
                                my $width = $all-mono
                                             ?? $ws.chars
                                             !! duospace-width-core($ws, 0);
                                if $width {
                                    # A single cell-width space must always fit
                                    # (otherwise the previous line would have been
                                    # finished already, resulting in a new partial
                                    # that would have room).

                                    # Determine whether the squash should be to a
                                    # width-2 IDEOGRAPHIC SPACE, or just a normal
                                    # width-1 SPACE character
                                    my $avail = $!wrap-width - $pos;
                                    my $wants-ideo = $avail >= 2 && $width >= 2
                                                     && $ws.contains("\x3000");
                                    my $space = $wants-ideo ?? "\x3000" !! ' ';
                                    my $need  = $wants-ideo + 1;
                                    my $piece = $span.new(:$string-span, :$color,
                                                          text => $space);

                                    $need < $avail ?? add-to-partial($piece, $need)
                                                   !! finish-line($piece);
                                }
                            }

                            # Remember whitespace state for next span
                            $after-ws = True;
                        }

                        # Second half: NON-whitespace run
                        if $nws {
                            # Remember whitespace state for next span
                            $after-ws = False;

                            my $avail = $!wrap-width - $pos;
                            my $width = $all-mono ?? $nws.chars
                                                  !! duospace-width-core($nws, 0);

                            # Run fits, just add it
                            if $width <= $avail {
                                my $piece = $span.new(:$string-span, :$color,
                                                      text => $nws);
                                $width < $avail ?? add-to-partial($piece, $width)
                                                !! finish-line($piece);
                            }
                            # We're in a word-oriented wrap mode, and this run will
                            # fit on a line by itself, so finish current line and
                            # add this piece to the next line
                            elsif $word-mode && $width <= $max-wrapped {
                                my $piece = $span.new(:$string-span, :$color,
                                                      text => $nws);
                                finish-line;
                                if $width == $max-wrapped {
                                    finish-line($piece);
                                }
                                else {
                                    add-to-partial($piece, $width);
                                    $after-ws = False;
                                }
                            }
                            # Need to split a run of NON-whitespace (a "word")
                            # across lines; check if it's monospace to use a
                            # faster splitting path
                            elsif $all-mono || is-monospace-core($nws, 0) {
                                # Work through $nws, chopping off pieces that
                                # finish lines (last line may be partial)
                                my $remainder = $nws;
                                while $remainder {
                                    my $avail  = $!wrap-width - $pos;
                                    my $length = $remainder.chars;
                                    my $first  = $remainder.substr(0, $avail);
                                    my $piece  = $span.new(:$string-span, :$color,
                                                           text => $first);
                                    if $length >= $avail {
                                        finish-line($piece);
                                        $remainder = $remainder.substr($avail);
                                    }
                                    else {
                                        add-to-partial($piece, $first.chars);
                                        $remainder = '';
                                        $after-ws  = False;
                                    }
                                }
                            }
                            # Need to split and run is duospace; account for wide
                            # chars and mixed width spans in splitting process.
                            # This is the SLOWEST PATH.
                            else {
                                # Work through $nws, chopping off pieces that
                                # finish lines (last line may be partial)
                                my $remainder = $nws;
                                while $remainder {
                                    # duospace-width(-core) is O(n), and
                                    # splitting may require O(log n) search, so
                                    # runtime for each wrapped line is O(n log n),
                                    # where n is the wrap-width.  Since the
                                    # number of wrapped lines will be approx.
                                    # the original text length divided by the
                                    # wrap-width, the result is O(N log n),
                                    # where N is the original text length and n
                                    # remains the wrap-width.

                                    my $avail  = $!wrap-width - $pos;
                                    my $more   = $avail div 2;
                                    my $width  = 0;
                                    my $length = $remainder.chars;

                                    # If this is guaranteed to be the last
                                    # piece because there's definitely enough
                                    # available space on the current partial
                                    # line, just directly add the final piece
                                    # and fall out to next run
                                    if $more >= $length {
                                        my $piece = $span.new(:$string-span,
                                                              :$color, :$remainder);
                                        $width = duospace-width-core($remainder, 0);

                                        if $width == $avail {
                                            finish-line($piece);
                                        }
                                        else {
                                            add-to-partial($piece, $width);
                                            $after-ws = False;
                                        }

                                        $remainder = '';
                                    }
                                    # Otherwise we might have to split again,
                                    # and finding the split point is going to
                                    # require some work.
                                    else {
                                        my $chars = 0;
                                        my $first = '';

                                        # Enough characters for at least half of
                                        # unused cells will always fit even if
                                        # initial chars are all wide, or up to
                                        # twice that if they are mostly narrow,
                                        # so converge on correct break using
                                        # pseudo-binary search.
                                        while $more > 0 && $chars < $length {
                                            $chars += $more;
                                            $first  = $remainder.substr(0, $chars);
                                            $width  = duospace-width-core($first, 0);
                                            $more   = ($avail - $width) div 2;
                                        }

                                        # Might be able to fit more width-0 or
                                        # width-1 characters after initial
                                        # binary search
                                        while $avail > $width && $chars < $length {
                                            # Try fitting one more character
                                            my $try-text  =
                                                $remainder.substr(0, $chars + 1);
                                            my $try-width =
                                                duospace-width-core($try-text, 0);

                                            # If it worked, commit
                                            if $avail >= $try-width {
                                                $width = $try-width;
                                                $first = $try-text;
                                                $chars++;
                                            }
                                        }

                                        # Did we fit any chars into this partial?
                                        my $first-length = $first.chars;
                                        if $first-length {
                                            # Managed to fit some, make a piece
                                            my $piece = $span.new(:$string-span, :$color,
                                                                  text => $first);
                                            $remainder = $remainder.substr($first-length);

                                            if $width == $avail {
                                                finish-line($piece);
                                            }
                                            else {
                                                add-to-partial($piece, $width);
                                                $after-ws = False;
                                            }
                                        }
                                        else {
                                            # Couldn't fit any, which means there
                                            # was only one cell left and the first
                                            # character is wide.  Close out this
                                            # line and try again with the next one.
                                            finish-line;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        # Full wrap/fill logic, per WrapMode
        given $mode {
            when GraphemeWrap {
                # Break lines between graphemes, without regard to "words"

                # For each hard line in the LineGroup ...
                for @$hard -> $line {
                    # Run the standard core span loop
                    span-loop($line);

                    # Add last partial line if any, ignoring a prefix-only line.
                    # Next line will start with no wrap prefix again.
                    unless $just-finished {
                        @wrapped.push(@partial);
                        @partial := [];
                        $pos      = 0;
                        $after-ws = True;
                    }
                }

                @wrapped
            }
            when WordWrap {
                # Break and wrap lines between words unless a single word is
                # too long to fit

                # For each hard line in the LineGroup ...
                for @$hard -> $line {
                    # Run the standard core span loop
                    span-loop($line);

                    # Add last partial line if any, ignoring a prefix-only line.
                    # Next line will start with no wrap prefix again.
                    unless $just-finished {
                        @wrapped.push(@partial);
                        @partial := [];
                        $pos      = 0;
                        $after-ws = True;
                    }
                }

                @wrapped
            }
            when GraphemeFill {
                # Attempt to backfill all short lines (except the last) in
                # order to create a mostly-rectangular block of graphemes

                # Run the standard core span loop for each LineGroup hard line
                span-loop($_) for @$hard;

                # Add last partial line if any, ignoring a prefix-only line
                @wrapped.push(@partial) unless $just-finished;

                @wrapped
            }
            when WordFill {
                # Attempt to backfill all short lines (except the last) with
                # words from later lines in order to create a more-rectangular
                # block of word spans

                # Run the standard core span loop for each LineGroup hard line
                span-loop($_) for @$hard;

                # Add last partial line if any, ignoring a prefix-only line
                @wrapped.push(@partial) unless $just-finished;

                @wrapped
            }
            default {
                die "Don't know how to handle WrapMode $mode";
            }
        }
    }

    #| OPTIONAL OVERRIDE: Skip forward to first visible LineGroup
    method span-line-start(UInt:D $start) {
        # Default: No special skip, just start at the beginning of the buffer
        0, 0
    }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my $t0 = nano;

        # Phase 1: Jump forward to first visible LineGroup if possible
        my ($i, $pos) = self.span-line-start($start);

        # Phase 2: Search for lines overlapping range and add them to @found
        my @found;
        while $i < @!line-groups {
            my $id    = @!line-groups[$i++].id;
            my $lines = $!wrap-style.wrap-mode == NoWrap
                        ?? %!hard-lines{$id}
                        !! %!wrapped-lines{$id} //= self.wrap-lines($id);

            my $prev  = $pos;
            $pos += $lines.elems;
            next if $start >= $pos;

            @found.append($start > $prev ?? @$lines[($start - $prev)..*]
                                         !! @$lines);
            last if @found >= $wanted;
        }

        self.debug-elapsed($t0);

        @found
    }
}
