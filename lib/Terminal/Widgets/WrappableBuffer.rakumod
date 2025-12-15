# ABSTRACT: SpanBuffer extension allowing line wrapping and fills

use nano;

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
#| *Wrap variants can only split lines; *Fill variants can merge them.
enum Terminal::Widgets::WrapMode is export
    < NoWrap GraphemeWrap WordWrap GraphemeFill WordFill >;

#| Style selection for wrapping/filling modes
class Terminal::Widgets::WrapStyle {
    has Terminal::Widgets::WrapMode:D $.wrap-mode = NoWrap;
    has Bool:D $.compress-whitespace = False;
    has Str:D  $.wrapped-line-prefix = '';
}


#| A SpanBuffer extension handling line wraps and fills
role Terminal::Widgets::WrappableBuffer
does Terminal::Widgets::SpanBuffer {
    has Terminal::Widgets::LineGroup:D @.line-groups;
    has Terminal::Widgets::WrapStyle:D $.wrap-style .= new;

    has UInt:D $!hard-line-max-width = 0;
    has UInt:D $!hard-line-count     = 0;
    has UInt:D %!hard-line-width;
    has        %!hard-lines;

    has UInt:D $!wrap-width = self.content-width;
    has        %!wrapped-lines;

    #| Set wrap-style and clear wrap caches
    method set-wrap-style(Terminal::Widgets::WrapStyle:D $new-style) {
        if  $!wrap-style !=== $new-style {
            $!wrap-style    = $new-style;
            %!wrapped-lines = Empty;
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

    #| Determine if buffer is completely empty
    method empty() { !@!line-groups }

    #| Insert a group of lines (as some TextContent variant) into the buffer
    #| at a given $pos, defaulting to appending at the end
    multi method insert-line-group(TextContent:D $content,
                                   UInt:D $pos = @!line-groups.elems) {
        self.add-line-group(Terminal::Widgets::LineGroup.new(:$content), $pos)
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

        # Remove LineGroup from buffer and delete hard-lines/wrapped-lines
        # cache entries
        @!line-groups.splice($pos, 1);
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
        my $mode = $!wrap-style.wrap-mode;
        my $hard = %!hard-lines{$id};

        # Quick exit: Not filling, and wrap-width is wide enough so that
        #             normal wrapping won't affect this LineGroup
        return $hard if $mode == NoWrap || $mode <= WordWrap
                     && $!wrap-width >= %!hard-line-width{$id};

        # XXXX: STUB, just hand back hard lines
        $hard
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
