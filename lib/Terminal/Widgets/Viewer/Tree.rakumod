# ABSTRACT: A viewer/browser for a Volatile::Tree

use Terminal::Widgets::Events;
use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::SpanBuffer;
use Terminal::Widgets::Focusable;
use Terminal::Widgets::Volatile::Tree;

constant VTree = Terminal::Widgets::Volatile::Tree;


my role DisplayNode {
    has DisplayNode $.parent;
    has VTree::Node $.data  is required;
    has UInt:D      $.depth is required;

    # REQUIRED: Total number of entries in this node and any visible children
    method branch-size(--> UInt:D) { ... }
}

my class DisplayLeaf does DisplayNode {
    method branch-size(--> 1) { }
}

my class DisplayParent does DisplayNode {
    has DisplayNode:D @.children;
    has Bool:D        $.expanded = False;

    method refresh-children() {
        my $depth  = $!depth + 1;
        @!children = $.data.children(:refresh).sort(*.short-name).map: {
            $_ ~~ VTree::Parent
                ?? DisplayParent.new(parent => self, data => $_, :$depth)
                !! DisplayLeaf.new(  parent => self, data => $_, :$depth)
        }
    }

    method toggle-expanded() { self.set-expanded(!$!expanded) }

    method set-expanded($!expanded) {
        if $!expanded {
            self.refresh-children;
        }
        else {
            @!children = Empty;
        }
    }

    method branch-size(--> UInt:D) {
        $!expanded ?? 1 + @!children.map(*.branch-size).sum
                   !! 1
    }
}


class Terminal::Widgets::Viewer::Tree
 does Terminal::Widgets::SpanBuffer
 does Terminal::Widgets::Focusable {
    has VTree::Node   $.root;
    has DisplayParent $.display-root is built(False);
    has               &.process-click;

    has @!flat-node-cache;
    has @!flat-line-cache;
    has $!max-line-width;

    # Auto-cache flattened nodes and displayable lines
    method flat-node-cache() {
        @!flat-node-cache ||= self.flattened-nodes($!display-root);
    }
    method flat-line-cache() {
        @!flat-line-cache ||= self.node-lines($!display-root);
    }
    method max-line-width() {
        $!max-line-width  ||= do {
            # my $locale = self.terminal.locale;
            # self.flat-line-cache.map({ $locale.width($_) }).max

            # XXXX: HACK while refactoring content model
            use Text::MiscUtils::Layout;
            self.flat-line-cache.map({ .map({ duospace-width(.text) }).sum }).max
        }
    }
    method clear-caches() {
        @!flat-node-cache = Empty;
        @!flat-line-cache = Empty;
        $!max-line-width  = 0;
    }

    # Fix x-max and y-max based on current display state
    method fix-scroll-maxes() {
        self.set-x-max(self.max-line-width);
        self.set-y-max($.display-root.branch-size);
        .note for $.x-max, $.y-max;
    }

    # Keep root and display-root in sync
    method set-root(VTree::Node:D $!root) { self!remap-root }
    method !remap-root() {
        $!display-root = DisplayParent.new(data => $!root, depth => 0);
        self.clear-caches;
    }

    #| Provide a span line chunk for SpanBuffer display
    method span-line-chunk(UInt:D $start, UInt:D $wanted) {
        my @lines := self.flat-line-cache;
        my $count  = @lines.elems;
        my $end    = $start + $wanted - 1;

        self.fix-scroll-maxes;

        $count > $end ?? @lines[$start .. $end]
                      !! @lines[$start .. *]
    }

    #| Displayable lines for a given node
    method node-lines($node) {
        my $is-parent  = $node ~~ DisplayParent && $node.expanded;
        my $first-line = [ self.prefix-string($node),
                           self.node-content($node) ];

        $is-parent ?? ($first-line,
                       $node.children.map({ self.node-lines($_).Slip })).flat
                   !! ($first-line, )
    }

    #| Flat list of displayable nodes starting at a given node
    method flattened-nodes($node) {
        my $is-parent = $node ~~ DisplayParent && $node.expanded;
        $is-parent ?? ($node, |$node.children.map({ self.flattened-nodes($_).Slip }))
                   !! ($node, )
    }

    #| Prefix for first line of a given node
    method prefix-string($node) {
        span('',   '  ' x $node.depth
                 ~ ($node ~~ DisplayParent ?? self.arrows()[+$node.expanded] !! ' ')
                 ~ ' ')
    }

    #| Displayed content for a given node itself, not including children
    method node-content($node) {
        span('', $node.data.short-name)
    }

    #| Arrow glyphs for given terminal capabilities
    method arrows($caps = self.terminal.caps) {
        my constant %arrows =
            ASCII => « > v »,
            MES2  => « > ∨ »,
            Uni7  => « ⮞ ⮟ »;

        $caps.best-symbol-choice(%arrows)
    }

    method line-to-display-node($line) {
        self.flat-node-cache[$line]
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Take focus even if clicked on framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled and within content area, move cursor and process click
        if $.enabled {
            my ($x, $y, $w, $h) = $event.relative-to-content-area(self);

            if 0 <= $x < $w && 0 <= $y < $h {
                my $clicked-line = $.y-scroll + $y;
                my $node = self.line-to-display-node($clicked-line);

                if $node ~~ DisplayParent {
                    $node.toggle-expanded;
                    self.clear-caches;
                    self.fix-scroll-maxes;
                    self.refresh-for-scroll;
                }

                if $node {
                    $_($node) with &!process-click;
                }
            }
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }
}
