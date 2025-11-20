# ABSTRACT: A viewer/browser for a Volatile::Tree

use Terminal::Widgets::Widget;
use Terminal::Widgets::Scrollable;
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
   is Terminal::Widgets::Widget
 does Terminal::Widgets::Scrollable
 does Terminal::Widgets::Focusable {
    has VTree::Node   $.root;
    has DisplayParent $.display-root is built(False);

    # Keep root and display-root in sync
    method set-root(VTree::Node:D $!root) { self!remap-root }
    method !remap-root() {
        $!display-root = DisplayParent.new(data => $!root, depth => 0);
    }

    method draw-content() {
        my @lines = self.node-lines($!display-root);
        .note for @lines;
    }

    #| Displayable lines for a given node
    method node-lines($node) {
        my $is-parent  = $node ~~ DisplayParent;
        my $first-line = self.prefix-string($node)
                       ~ self.node-content($node);

        $is-parent ?? ($first-line,
                       $node.children.map({ self.node-lines($_).Slip })).flat
                   !! ($first-line, )
    }

    #| Prefix for first line of a given node
    method prefix-string($node) {
          '  ' x $node.depth
        ~ ($node ~~ DisplayParent ?? self.arrows()[+$node.expanded] !! ' ')
        ~ ' '
    }

    #| Displayed content for a given node itself, not including children
    method node-content($node) {
        $node.data.short-name
    }

    #| Arrow glyphs for given terminal capabilities
    method arrows($caps = self.terminal.caps) {
        my constant %arrows =
            ASCII => « > v »,
            MES2  => « > ∨ »,
            Uni7  => « ⮞ ⮟ »;

        $caps.best-symbol-choice(%arrows)
    }
}
