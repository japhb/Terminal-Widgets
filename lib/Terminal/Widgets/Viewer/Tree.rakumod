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
    method expanded(--> False) { }
    method branch-size(--> 1)  { }
}

my class DisplayParent does DisplayNode {
    has DisplayNode:D @.children;
    has Bool:D        $.expanded = False;
    has               &.sort-by is required;

    #| Refresh children from volatile data and recreate DisplayNodes as needed
    method refresh-children() {
        my $depth  = $!depth + 1;
        @!children = $.data.children(:refresh).sort(&!sort-by).map: {
            $_ ~~ VTree::Parent
                ?? DisplayParent.new(parent => self, data => $_, :$depth, :&!sort-by)
                !! DisplayLeaf.new(  parent => self, data => $_, :$depth)
        }
    }

    #| Toggle expanded state (using set-expanded)
    method toggle-expanded() { self.set-expanded(!$!expanded) }

    #| Set expanded state, refreshing or emptying children as appropriate
    method set-expanded($!expanded) {
        if $!expanded {
            self.refresh-children;
        }
        else {
            @!children = Empty;
        }
    }

    #| Number of nodes in visible child branches, including self
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
    has DisplayNode   $.current-node is built(False);
    has               &.sort-by       = *.short-name;
    has               &.process-click;

    has @!flat-node-cache;
    has @!flat-line-cache;
    has $!max-line-width;


    # Keep root and display-root in sync
    method set-root(VTree::Node:D $!root) { self!remap-root }
    method !remap-root() {
        $!display-root = DisplayParent.new(data => $!root, depth => 0, :&.sort-by);
        self.clear-caches;
        self.select-node($!display-root);
    }

    # Clear caches when setting sort-by
    method set-sort-by(&!sort-by) { self.clear-caches }

    # Auto-cache flattened nodes and displayable lines
    method flat-node-cache() {
        @!flat-node-cache ||= do {
            my $debug = +($*DEBUG // 0);
            my $t0    = now;
            self.flattened-nodes($!display-root, my @n);
            note sprintf("flattened-nodes: %.3fms (%d elems)",
                         1000 * (now - $t0), @n.elems) if $debug;
            @n
        }
    }
    method flat-line-cache() {
        @!flat-line-cache ||= do {
            my $debug = +($*DEBUG // 0);
            my $t0    = now;
            self.node-lines($!display-root, my @l);
            note sprintf("node-lines: %.3fms (%d elems)",
                         1000 * (now - $t0), @l.elems) if $debug;
            @l
        }
    }
    method max-line-width() {
        $!max-line-width  ||= do {
            # my $locale = self.terminal.locale;
            # self.flat-line-cache.map({ $locale.width($_) }).max

            # XXXX: HACK while refactoring content model
            my $debug = +($*DEBUG // 0);
            my $t0    = now;
            my $max   = self.flat-line-cache.map({   .[0].text.chars
                                                   + .[1].text.chars }).max;
            note sprintf("max-line-width: %.3fms (%d elems)",
                         1000 * (now - $t0), @!flat-line-cache.elems) if $debug;
            $max
        }
    }
    method clear-caches() {
        @!flat-node-cache = Empty;
        @!flat-line-cache = Empty;
        $!max-line-width  = 0;
    }

    #| Fix x-max and y-max based on current display state
    method fix-scroll-maxes() {
        self.set-x-max(self.max-line-width);
        self.set-y-max($.display-root.branch-size);
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

    #| Flatten displayable lines for a given node into array @lines
    method node-lines($node, @lines) {
        @lines.push: [ self.prefix-string($node),
                       self.node-content($node) ];
        if $node.expanded {
            self.node-lines($_, @lines) for $node.children;
        }
    }

    #| Flatten displayable nodes starting at a given node into array @nodes
    method flattened-nodes($node, @nodes) {
        @nodes.push: $node;
        if $node.expanded {
            self.flattened-nodes($_, @nodes) for $node.children;
        }
    }

    #| Prefix for first line of a given node
    method prefix-string($node) {
        state @prefix-cache;
        my $expanded = $node ~~ DisplayParent ?? +$node.expanded !! 2;
        @prefix-cache[$node.depth][$expanded] //=
            span('',   '  ' x $node.depth
                     ~ ($node ~~ DisplayParent ?? self.arrows()[+$node.expanded] !! ' ')
                     ~ ' ')
    }

    #| Displayed content for a given node itself, not including children
    method node-content($node) {
        my $color = $node === $!current-node ?? 'inverse' !! '';
        span($color, $node.data.short-name)
    }

    #| Arrow glyphs for given terminal capabilities
    method arrows($caps = self.terminal.caps) {
        my constant %arrows =
            ASCII => « > v »,
            MES2  => « > ∨ »,
            Uni7  => « ⮞ ⮟ »;

        $caps.best-symbol-choice(%arrows)
    }

    #| Convert a displayed line index to the matching DisplayNode
    method line-to-display-node(UInt:D $line) {
        self.flat-node-cache[$line]
    }

    #| Determine the displayed line index of a given DisplayNode
    method display-node-to-line($node) {
        self.flat-node-cache.first(* === $node, :k)
    }

    #| Remove highlight from a node
    method remove-highlight($node) {
        my $line = self.display-node-to-line($node);
        return unless $line.defined;

        my @line-spans := self.flat-line-cache[$line];
        my $color       = @line-spans[1].color.subst('inverse ', '');
        @line-spans[1]  = span($color, @line-spans[1].text);
    }

    #| Add a highlight to a node
    method add-highlight($node) {
        self.ensure-parents-expanded($node);
        my $line = self.display-node-to-line($node);
        return unless $line.defined;

        my @line-spans := self.flat-line-cache[$line];
        @line-spans[1]  = span('inverse ' ~ @line-spans[1].color,
                                            @line-spans[1].text);
    }

    #| Select a given node as current, expanding parents if needed and
    #| processing a "click" on the node
    method select-node($node) {
        if $!current-node !=== $node {
            self.remove-highlight($!current-node);
            $!current-node = $node;
            self.ensure-parents-expanded($node);
            self.add-highlight($node);
            self.full-refresh;
            $_($node) with &!process-click;
            # XXXX: Ensure visible?
        }
    }

    #| Select the immediately previous node from the current one,
    #| in display order (so skipping over collapsed nodes)
    method select-prev-node() {
        my $line = self.display-node-to-line($!current-node);
        return unless $line;

        if self.line-to-display-node($line - 1) -> $node {
            self.select-node($node);
            self.ensure-y-span-visible($line - 1, $line);
            self.refresh-for-scroll;
        }
    }

    #| Select the immediately next node from the current one,
    #| in display order (so skipping over collapsed nodes)
    method select-next-node() {
        my $line = self.display-node-to-line($!current-node);
        return unless $line.defined;

        if self.line-to-display-node($line + 1) -> $node {
            self.select-node($node);
            self.ensure-y-span-visible($line, $line + 1);
            self.refresh-for-scroll;
        }
    }

    #| Perform cache clears and scroll changes needed for changed expanded state
    method refresh-for-expand-change() {
        self.clear-caches;
        self.fix-scroll-maxes;
        self.refresh-for-scroll;
    }

    #| Walk up the parents from a given DisplayNode, making sure they are
    #| expanded so that the node can be made visible
    method ensure-parents-expanded($node) {
        my $parent  = $node.parent;
        my $changed = False;

        while $parent {
            unless $parent.expanded {
                $parent.set-expanded(True);
                $changed = True;
            }
            $parent .= parent;
        }

        self.refresh-for-expand-change if $changed;
    }

    #| Set a node's expanded state, refreshing if it changed.  Silently
    #| ignores non-DisplayParent nodes.
    method set-node-expanded($node, Bool:D $expanded = True) {
        if $node ~~ DisplayParent && $node.expanded != $expanded {
            $node.set-expanded($expanded);
            self.refresh-for-expand-change;
        }
    }

    #| Toggle a node's expanded state, and refresh.  Silently ignores
    #| non-DisplayParent nodes.
    method toggle-node-expanded($node) {
        if $node ~~ DisplayParent {
            $node.toggle-expanded;
            self.refresh-for-expand-change;
        }
    }

    #| Handle keyboard events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorDown  => 'node-next',
            CursorUp    => 'node-prev',
            CursorRight => 'node-expand',
            CursorLeft  => 'node-collapse',
            Ctrl-M      => 'node-toggle',   # Enter
            Ctrl-I      => 'focus-next',    # Tab
            ShiftTab    => 'focus-prev',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'node-next'     { self.select-next-node }
            when 'node-prev'     { self.select-prev-node }
            when 'node-expand'   { self.set-node-expanded($.current-node, True)  }
            when 'node-collapse' { self.set-node-expanded($.current-node, False) }
            when 'node-toggle'   { self.toggle-node-expanded($.current-node)     }
            when 'focus-next'    { self.focus-next }
            when 'focus-prev'    { self.focus-prev }
        }
    }

    #| Handle mouse events
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

                self.select-node($node);
                self.toggle-node-expanded($node);

                # Skip final full-refresh, since toggle-node-expanded will
                # already do a refresh-for-scroll, which does a full-refresh
                return;
            }
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }
}
