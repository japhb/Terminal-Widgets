# ABSTRACT: A text widget that has clickable lines / a selected line.


use Terminal::Widgets::Layout;
use Terminal::Widgets::Events;
use Terminal::Widgets::Focusable;
use Terminal::Widgets::SpanWrappingAndHighlighting;


#| Layout node for a tree viewer widget
class Terminal::Widgets::Layout::TreeView
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'tree-view' }
}


role Terminal::Widgets::TreeViewNode {
    #| A single line of text for this node.
    has Str $.text;

    #| Some identifier. Can be any object.
    #| Optional in RichTreeViewNodes, mandatory in ShallowTreeViewNodes.
    #| Providing an ID for each node will allow saving and restoring
    #| the state of each node more reliably in the case of a changing tree
    #| structure.
    has $.id;

    method id-for-props() {
        $!id
    }

    method leaf(--> Bool) { ... }
}

role Terminal::Widgets::ShallowTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| Optional. If set to True, the node will hide the "expand" marker
    #| of the node, even if it wasn't opened yet.
    has Bool $!leaf is built = False;
    method leaf(--> Bool) { $!leaf }
}

role Terminal::Widgets::RichTreeViewNode
  does Terminal::Widgets::TreeViewNode {
    #| This nodes children. If empty, it's a leaf node.
    has Terminal::Widgets::RichTreeViewNode @.children;
    method leaf(--> Bool) { @!children.elems == 0 }
}


class Terminal::Widgets::TreeView
 does Terminal::Widgets::SpanWrappingAndHighlighting
 does Terminal::Widgets::Focusable {
    method layout-class() { Terminal::Widgets::Layout::TreeView }

    my class NodeProperties {
        has $.id;
        has Bool $.expanded is rw;
    }

    my class WrappedRichNode
      does Terminal::Widgets::ShallowTreeViewNode {
        has Terminal::Widgets::RichTreeViewNode $.orig;

        method id-for-props() {
            $!orig.id // $!id
        }
        method id-for-children() {
            $!id
        }
    }

    my class DisplayNode {
        has Terminal::Widgets::TreeViewNode $.node;
        has DisplayNode @.children;
        has Int $.depth;
        has DisplayNode $.parent is rw;

        submethod TWEAK() {
            $_.parent = self for @!children;
        }

        method orig-node() {
            if $!node ~~ WrappedRichNode {
                $!node.orig
            }
            else {
                $!node
            }
        }

        method set-children(@!children) {
            $_.parent = self for @!children;
        }

        method line-count() {
            1 + [+] @!children.map: { $_.line-count }
        }

        method find-by-id($id) {
            if $!node.id-for-props eqv $id {
                self
            }
            else {
                for @!children -> $child {
                    return $_ with $child.find-by-id($id);
                }
            }
        }
    }

    #| A function that will, when given a node ID, will return a list of that
    #| nodes children. When passed Nil as the node ID, it must return the top
    #| level nodes.
    #| sub get-children($node-id --> List[ShallowTreeViewNodes])
    has &.get-children;

    #| Alternatively to &.get-children, one can just pass a complete
    #| RichTreeViewNode list.
    has Terminal::Widgets::RichTreeViewNode $.root-node;

    #| DisplayNode trees. Contains a list of all visible nodes. Not necessarily
    #| on the screen, but not hidden in a collapsed parent.
    has $!dn-root;

    #| Node
    has NodeProperties @.node-props;

    has &.get-node-prefix;

    has &.process-click;

    submethod TWEAK(:$wrap, :$root-node = Any, :$get-children = Any, :$get-node-prefix = Any) {
        # The following is a workaround of https://github.com/rakudo/rakudo/issues/5599
        $!wrap = NoWrap;
        $!wrap = $wrap if $wrap;

        die '$root-node and &get-children can not be set both' if $root-node.defined && $get-children.defined;

        if !$get-children.defined && !$root-node.defined {
            self.set-root-node: Terminal::Widgets::RichTreeViewNode.new;
        }
        elsif $root-node.defined {
            self.set-root-node: $root-node;
        }
        elsif $get-children.defined {
            &!get-children = &$get-children;
        }


        if $get-node-prefix.defined {
            &!get-node-prefix = &$get-node-prefix;
        }
        else {
            &!get-node-prefix = sub (Int $level, Bool $expanded, Bool $leaf, Bool $last) {
                ($level == 0
                    ?? ''
                    !! ' ' x ($level - 1)
                        ~ ($last ?? '└' !! '├')
                )
                ~ ($leaf
                    ?? ' '
                    !! ($expanded ?? '⮟' !! '⮞')
                )
                ~ ' '
            }
        }

        self!refresh-dn;
    }

    sub get-children-of-tree($root-node, $id) {
        # In a wrapped tree, we'll populate the ID with a list of indexes
        # leading to the node.
        my $n = $root-node;
        my @ids;
        if !($id === Nil) {
            for @$id -> $index {
                $n = $n.children[$index];
            }
            @ids = @$id;
        }
        $n.children.kv.map: -> $i, $node {
            WrappedRichNode.new:
                id => (|@ids, $i),
                orig => $node,
                leaf => $node.children.elems == 0,
                text => $node.text,
            ;
        }
    }

    method set-root-node($!root-node) {
        &!get-children = sub ($id) {
            get-children-of-tree($!root-node, $id);
        }
        self!refresh-dn;
    }

    method set-get-children(&!get-children) {
        $!root-node = Terminal::Widgets::RichTreeViewNode.new;
        self!refresh-dn;
    }

    method !dn-get-prefix($dn) {
        my $expanded = self!prop-for-id($dn.node.id-for-props).expanded;
        &!get-node-prefix($dn.depth, $expanded, $dn.node.leaf, $dn === $dn.parent.children.first: :end)
    }

    method !dn-get-text($dn) {
        my @lines = self!dn-get-prefix($dn) ~ $dn.node.text;
        @lines.append(self!dn-get-text($_)) for $dn.children;
        @lines
    }

    method !nodes-to-dns(@nodes, $depth) {
        @nodes.kv.map: -> $index, $node {
            my @children = self!prop-for-id($node.id-for-props).expanded
                ?? self!nodes-to-dns(&!get-children($node.id), $depth + 1)
                !! ();
            DisplayNode.new(
                :$node,
                :@children,
                :$depth,
            )
        }
    }

    method !refresh-dn() {
        my @dns = self!nodes-to-dns(&!get-children(Nil), 0);
        $!dn-root = DisplayNode.new(
            :children(@dns),
            :depth(0),
        );

        my @lines = @dns.map: {
            self!dn-get-text: $_
        }
        # Ensure @lines is one line per entry.
        @lines .= map(*.lines.join);
        self!set-text(@lines.join("\n"));
    }

    method !prop-for-id($id) {
        for @!node-props -> $prop {
            return $prop if $prop.id eqv $id;
        }
        my $prop = NodeProperties.new(
                :$id,
            );
        @!node-props.push: $prop;
        $prop
    }

    method !line-to-dn($line-no) {
        sub line-to-dn-rec($pos is rw, $line, $dn) {
            return $dn if $pos == $line;
            for $dn.children -> $child {
                $pos++;
                return $_ with line-to-dn-rec($pos, $line, $child);
            }
        }

        # First child of the root is at pos 0, so the root is at pos -1.
        my $cur-line = -1;
        line-to-dn-rec($cur-line, $line-no, $!dn-root)
    }

    method !dn-to-line($needle) {
        sub dn-to-line-rec($pos is rw, $needle, $dn) {
            return $pos if $needle === $dn;
            for $dn.children -> $child {
                $pos++;
                return $_ with dn-to-line-rec($pos, $needle, $child);
            }
        }

        # First child of the root is at pos 0, so the root is at pos -1.
        my $cur-line = -1;
        dn-to-line-rec($cur-line, $needle, $!dn-root)
    }

    method !dn-for-id($id) {
        $!dn-root.find-by-id: $id
    }

    method expand-node($id) {
        with self!dn-for-id($id) -> $dn {
            self!expand-dn: $dn;
        }
        else {
            self!prop-for-id($id).expanded = True;
        }
    }

    method !expand-current-node() {
        my $line = $!cursor-y;
        my $dn = self!line-to-dn($line);
        self!expand-dn: $dn;
    }

    method !expand-dn($dn) {
        my $prop = self!prop-for-id($dn.node.id-for-props);
        if !$prop.expanded {
            $prop.expanded = True;
            my @children = &!get-children($dn.node.id);
            if @children {
                my @dns = self!nodes-to-dns(@children, $dn.depth + 1);
                $dn.set-children: @dns;

                my @lines = self!dn-get-text: $dn;
                # Ensure @lines is one line per entry.
                @lines .= map(*.lines.join);

                my $line = self!dn-to-line: $dn;

                self!splice-lines($line, 1, @lines.join("\n"));
            }
        }
    }

    method collapse-node($id) {
        with self!dn-for-id($id) -> $dn {
            self!collapse-dn: $dn;
        }
        else {
            self!prop-for-id($id).expanded = False;
        }
    }

    method !collapse-current-node() {
        my $line = $!cursor-y;
        my $dn = self!line-to-dn($line);
        self!collapse-dn: $dn;
    }

    method !collapse-dn($dn) {
        self!prop-for-id($dn.node.id-for-props).expanded = False;
        my $old-line-count = $dn.line-count;
        $dn.set-children: ();
        my $line = self!dn-to-line: $dn;
        my @lines = self!dn-get-text: $dn;
        self!splice-lines($line, $old-line-count, @lines);
    }

    method !toggle-expand-dn($dn) {
        if self!prop-for-id($dn.node.id-for-props).expanded {
            self!collapse-dn: $dn;
        }
        else {
            self!expand-dn: $dn;
        }
    }

    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            CursorDown  => 'select-next-line',
            CursorUp    => 'select-prev-line',
            CursorRight => 'expand-node',
            CursorLeft  => 'collapse-node',
            Ctrl-I      => 'focus-next',    # Tab
            ShiftTab    => 'focus-prev',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            when 'select-next-line' { self!select-line($!cursor-y + 1) }
            when 'select-prev-line' { self!select-line($!cursor-y - 1) }
            when 'expand-node'      { self!expand-current-node }
            when 'collapse-node'    { self!collapse-current-node }
            when 'focus-next'       { self.focus-next }
            when 'focus-prev'       { self.focus-prev }
        }
    }

    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Take focus even if clicked on framing instead of content area
        self.toplevel.focus-on(self);

        # If enabled and within content area, move cursor and process click
        if $.enabled {
            my ($x, $y, $w, $h) = $event.relative-to-content-area(self);

            if 0 <= $x < $w && 0 <= $y < $h {
                my $clicked-display-line = $!first-display-line + $y;
                my $line-index = @!dl-l[$clicked-display-line min @!dl-l.end];
                $!cursor-y = $line-index;
                my $dn = self!line-to-dn: $line-index;
                my $rel-y = $y - @!l-dl[$line-index];

                $x = self!display-pos-to-line-pos(@!lines[$line-index],
                                                  self.x-scroll + $x, $rel-y);
                $!cursor-x = $x min self!chars-in-line(@!lines[$line-index]) - 1;

                my $locale = $.terminal.locale;
                my $prefix-len = $locale.width(self!dn-get-prefix($dn));
                if $!cursor-x < $prefix-len {
                    self!toggle-expand-dn($dn);
                }
                else {
                    $_($dn.orig-node, $!cursor-x - $prefix-len, 0) with &!process-click;
                }
            }
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }
}


# Register TreeView as a buildable widget type
Terminal::Widgets::TreeView.register;
