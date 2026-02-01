# ABSTRACT: SpanBuffer extension allowing line wrapping and fills

use nano;

use Text::MiscUtils::Layout;

use Terminal::Widgets::Events;
use Terminal::Widgets::Terminal;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::Focusable;
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

    has Bool:D $.wrap-cursor-between-lines = True;

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
does Terminal::Widgets::SpanBuffer
does Terminal::Widgets::Focusable {
    has Terminal::Widgets::LineGroup:D @.line-groups;
    has Terminal::Widgets::WrapStyle:D $.wrap-style .= new(terminal => self.terminal);

    has &.process-click;

    has %.selected-span-info;
    has $.cursor-x = 0;
    has $.cursor-y = 0;

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
        my $content = TC::span-tree($line-group.content, line-group-id => $id);
        my $lines = %!hard-lines{$id} = self.hard-lines($content);

        # Update total hard line count and max hard line width
        my $widest = $lines.map(*.map(*.width).sum).max max 0;
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

        # Break into lines, then make sure every StringSpan knows its hard line
        # number within the line group before rendering to RenderSpans
        $as-tree.lines.kv.map(-> $i, $line {
                                  $line.map({
                                      .attributes<lg-hard-line> = $i;
                                      .render
                                  }).eager
                              }).eager
    }

    #| Clear all contents, caches, and selections from the buffer
    method clear() {
        @!line-groups         = Empty;
        %!selected-span-info  = Empty;
        %!hard-line-width     = Empty;
        %!hard-lines          = Empty;
        %!wrapped-lines       = Empty;

        $!cursor-x            = 0;
        $!cursor-y            = 0;
        $!hard-line-max-width = 0;
        $!hard-line-count     = 0;
    }

    #| Remove a LineGroup from the buffer and update caches appropriately
    multi method remove-line-group(Terminal::Widgets::LineGroup:D $line-group) {
        self.remove-line-group($line-group.id)
    }

    #| Remove a LineGroup by id and update caches appropriately
    multi method remove-line-group(UInt:D $id) {
        # Find location of LineGroup with this $id within buffer
        my $pos = @!line-groups.first(*.id == $id, :k) //
            die "LineGroup id #$id does not exist in this self.gist-name()";

        # Remove LineGroup from buffer, reduce hard-line-count, and delete
        # hard-lines/wrapped-lines cache entries
        @!line-groups.splice($pos, 1);
        $!hard-line-count -= %!hard-lines{$id}.elems;
        %!hard-lines{$id}:delete;
        %!wrapped-lines{$id}:delete;

        # Update hard-line-max-width if this entry was the widest
        my $hl-width = %!hard-line-width{$id}:delete;
        $!hard-line-max-width = (%!hard-line-width.values.max // 0) max 0
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
                            # XXXX: Handle joining and non-breaking spaces correctly

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
                                # Need to split a run of whitespace, but can
                                # optimize because it is all width-1 spaces
                                elsif $all-mono || $width == $ws.chars
                                                   && is-monospace-core($ws, 0) {
                                    # Work through the whitespace, chopping off
                                    # pieces that finish lines (last line may be
                                    # partial)
                                    my $remainder = $ws;
                                    while $remainder {
                                        my $avail = $!wrap-width - $pos;
                                        my $first = $remainder.substr(0, $avail);
                                        my $piece = $span.new(:$string-span, :$color,
                                                              text => $first);

                                        $width = $first.chars;
                                        $width < $avail
                                            ?? add-to-partial($piece, $width)
                                            !! finish-line($piece);

                                        $after-ws  = True;
                                        $remainder = $remainder.substr($width);
                                    }
                                }
                                # Need to split a run of spaces across lines,
                                # and the run contains width-0 or width-2 spaces
                                else {
                                    # Work through the whitespace, chopping off
                                    # pieces that finish lines (last line may be
                                    # partial)
                                    my $remainder = $ws;
                                    while $remainder {
                                        # There's only one Unicode whitespace char
                                        # with width > 1: U+3000 IDEOGRAPHIC SPACE
                                        # All the rest are 0 or 1.
                                        my $avail  = $!wrap-width - $pos;
                                        my $more   = $remainder.contains("\x3000")
                                                      ?? $avail div 2 !! $avail;
                                        my $width  = 0;
                                        my $length = $remainder.chars;

                                        # Last piece, because there's guaranteed
                                        # enough room?  Excellent, add it.
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
                                        # We might have to split again
                                        else {
                                            my $chars = 0;
                                            my $first = '';

                                            # Binary search forward for break point
                                            while $more > 0 && $chars < $length {
                                                $chars += $more;
                                                $first  = $remainder.substr(0, $chars);
                                                $width  = duospace-width-core($first, 0);
                                                $more   = ($avail - $width) div 2;
                                            }

                                            # Might be able to fit more width-0 or
                                            # width-1 spaces after initial binary search
                                            while $avail > $width && $chars < $length {
                                                # Try fitting one more space
                                                my $try-text  =
                                                    $remainder.substr(0, $chars + 1);
                                                my $try-width =
                                                    duospace-width-core($try-text, 0);

                                                # Break out if too wide now
                                                last unless $avail >= $try-width;

                                                # It worked, commit
                                                $width = $try-width;
                                                $first = $try-text;
                                                $chars++;
                                            }

                                            # Did we fit any chars into this partial?
                                            my $first-length = $first.chars;
                                            if $first-length {
                                                # Managed to fit some, make a piece
                                                my $piece = $span.new(:$string-span,
                                                                      :$color,
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
                                                # Couldn't fit any, which means
                                                # there was only one cell left
                                                # and the first space character
                                                # is wide.  Close out this line
                                                # and try again with the next one.
                                                finish-line;
                                            }
                                        }
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
                                        my $piece = $span.new(:$string-span, :$color,
                                                              text => $remainder);
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

                                            # Break out if too wide now
                                            last unless $avail >= $try-width;

                                            # It worked, commit
                                            $width = $try-width;
                                            $first = $try-text;
                                            $chars++;
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

    #| OPTIONAL OPTIMIZATION: Skip forward to first visible LineGroup
    method span-line-start(UInt:D $start) {
        # Default: No special skip, just start at the beginning of the buffer
        0, 0
    }

    #| OPTIONAL HOOK: Post-process the lines in a LineGroup before display
    method post-process-line-group($lg-id, $first-line, $start-line, $last-line, @lines) {
        # Default behavior: Just return the lines unchanged
        @lines
    }

    #| Grab a chunk of laid-out span lines to feed to SpanBuffer.draw-frame,
    #| post-processing any potentially-visible lines unless $skip-processing is True
    method span-line-chunk(UInt:D $start, UInt:D $wanted,
                           Bool:D :$skip-processing = False) {
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

            $lines = self.post-process-line-group($id, $prev, $start,
                                                  $start + $wanted - 1,
                                                  $lines)
                unless $skip-processing;

            @found.append($start > $prev ?? @$lines[($start - $prev)..*]
                                         !! @$lines);
            last if @found >= $wanted;
        }

        self.debug-elapsed($t0);

        @found
    }

    #| Find the rendered line (array of RenderSpans) for a given Y-index
    #| accounting for wrapping mode (or an undefined value if no such line
    #| exists)
    # XXXX: Both end-of-line and span-from-buffer-loc call rendered-line, and
    #       they are often used together; may be able to avoid duplicate calls.
    #       Use multi's for callers, which take either y or line?
    method rendered-line(UInt:D $y) {
        self.span-line-chunk($y, 1, :skip-processing)[0]
    }

    #| Calculate x-location of end of (possibly wrapped) line, or 0 if not found
    method end-of-line(UInt:D $y) {
        # Find spans for a given line; if it doesn't exist, return 0
        my $line = self.rendered-line($y) // return 0;

        # Sum duospace widths of all spans on line
        $line.map(*.width).sum
    }

    #| Convert from a buffer location to a render span (or Nil if not found)
    method span-from-buffer-loc(UInt:D $x, UInt:D $y) {
        # Find spans for a given line; if it doesn't exist, return Nil
        my $line = self.rendered-line($y) // return Nil;

        my $pos = 0;
        for @$line -> $span {
            my $next = $pos + $span.width;
            return $span if $pos <= $x < $next;
            $pos = $next;
        }

        # Location was past last span if any; try
        # returning last span or Nil if none on this line
        $line.elems ?? $line[*-1] !! Nil
    }

    #| Determine if x-location in a line is the second cell of a wide character
    # XXXX: This feels cacheable.  Perhaps a bitmap with 1's for second cells?
    method is-second-cell(UInt:D $x, UInt:D $y) {
        # Find spans for a given line; if it doesn't exist, return False
        my $line = self.rendered-line($y) // return False;

        my $pos = 0;
        for @$line -> $span {
            my $width = $span.width;
            my $next  = $pos + $width;

            # Found the right span, now look for proper cell
            if $pos <= $x < $next {
                # Monospace spans don't have wide chars, so no second cells
                my $text  = $span.text;
                my $chars = $text.chars;
                return False if $width == $chars && is-monospace-core($text, 0);

                # Duospace; march through span one character at a time
                for $text.comb {
                    my $w = duospace-width-core($_, 0);
                    return True if $w > 1 && $x == $pos + 1;
                    $pos += $w;
                }

                # Past end of span; return False
                return False
            }

            $pos = $next;
        }

        # Fell off the end of the line?  It's clearly not a second cell.
        False
    }

    #| Select a given span (and its hard line and line group); returns
    #| True if the selection action caused a full refresh, or False if not.
    method select-span($span --> Bool:D) {
        # Cache span info for selected span
        %!selected-span-info := $span ?? span-info($span) !! {};

        # No refresh occurred
        False
    }

    #| Move cursor one character previous, which may result in wrapping to the
    #| previous line, and ensure the cursor remains visible
    multi method cursor-char-prev() {
        # In a second cell and moving left?  Bump left before continuing.
        --$!cursor-x if self.is-second-cell($!cursor-x, $!cursor-y);

        --$!cursor-x;
        if $!cursor-x < 0 {
            if $!cursor-y && $!wrap-style.wrap-cursor-between-lines {
                # Went past left edge, move to end of previous line
                $!cursor-x = self.end-of-line(--$!cursor-y);
                self.ensure-y-span-visible($!cursor-y, $!cursor-y);
            }
            else {
                # No previous line to move to, or cross-line wrapping
                # prohibited, so just stop at left edge
                $!cursor-x = 0;
            }
        }

        self.ensure-x-span-visible($!cursor-x, $!cursor-x);
        my $span = self.span-from-buffer-loc($!cursor-x, $!cursor-y);
        my $refreshed = self.select-span($span);
        self.full-refresh unless $refreshed;
    }

    #| Move cursor to next character, which may result in wrapping to the
    #| next line, and ensure the cursor remains visible
    multi method cursor-char-next() {
        my $eol = self.end-of-line($!cursor-y);
        if ++$!cursor-x > $eol {
            if $!cursor-y < $.y-max - 1
            && $!wrap-style.wrap-cursor-between-lines {
                $!cursor-x = 0;
                $!cursor-y++;
                self.ensure-y-span-visible($!cursor-y, $!cursor-y);
            }
            else {
                # No next line to move to, or cross-line wrapping
                # prohibited, so just stop at right edge
                $!cursor-x = $eol;
            }
        }

        # Moved right into a second cell?  Move right a second time.
        ++$!cursor-x if self.is-second-cell($!cursor-x, $!cursor-y);

        self.ensure-x-span-visible($!cursor-x, $!cursor-x);
        my $span = self.span-from-buffer-loc($!cursor-x, $!cursor-y);
        my $refreshed = self.select-span($span);
        self.full-refresh unless $refreshed;
    }

    #| Move cursor to previous line and ensure the cursor remains visible
    multi method cursor-line-prev() {
        if $!cursor-y {
            $!cursor-y--;
            self.ensure-y-span-visible($!cursor-y, $!cursor-y);

            my $x = $!cursor-x min self.end-of-line($!cursor-y);
            self.ensure-x-span-visible($x, $x);

            my $span = self.span-from-buffer-loc($!cursor-x, $!cursor-y);
            my $refreshed = self.select-span($span);
            self.full-refresh unless $refreshed;
        }
    }

    #| Move cursor to next line and ensure the cursor remains visible
    multi method cursor-line-next() {
        if $!cursor-y < $.y-max - 1 {
            $!cursor-y++;
            self.ensure-y-span-visible($!cursor-y, $!cursor-y);

            my $x = $!cursor-x min self.end-of-line($!cursor-y);
            self.ensure-x-span-visible($x, $x);

            my $span = self.span-from-buffer-loc($!cursor-x, $!cursor-y);
            my $refreshed = self.select-span($span);
            self.full-refresh unless $refreshed;
        }
    }

    #| Handle keyboard events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorLeft  => 'char-prev',
            CursorRight => 'char-next',
            CursorUp    => 'line-prev',
            CursorDown  => 'line-next',
            Ctrl-I      => 'focus-next',    # Tab
            ShiftTab    => 'focus-prev',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'char-prev'  { self.cursor-char-prev }
            when 'char-next'  { self.cursor-char-next }
            when 'line-prev'  { self.cursor-line-prev }
            when 'line-next'  { self.cursor-line-next }
            when 'focus-next' { self.focus-next }
            when 'focus-prev' { self.focus-prev }
        }
    }

    #| Handle mouse events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Take focus even if clicked on framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled and within content area, determine clicked span and
        # process click on it
        if $.enabled {
            my ($x, $y, $w, $h) = $event.relative-to-content-area(self);

            if 0 <= $x < $w && 0 <= $y < $h {
                $!cursor-x = $.x-scroll + $x;
                $!cursor-y = $.y-scroll + $y;
                my $span   = self.span-from-buffer-loc($!cursor-x, $!cursor-y);

                my $refreshed = self.select-span($span);
                $_($span, $!cursor-x, $!cursor-y) with &!process-click;

                # If selecting the span caused a refresh, skip the outer one
                return if $refreshed;
            }
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }
}
