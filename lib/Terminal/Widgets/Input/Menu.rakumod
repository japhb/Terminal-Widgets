# ABSTRACT: Simple single-selection menu

use Terminal::Widgets::Layout;
use Terminal::Widgets::Events;
use Terminal::Widgets::Input;
use Terminal::Widgets::Widget;
use Terminal::Widgets::TextContent;


#| Layout node for a menu input widget
class Terminal::Widgets::Layout::Menu
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'menu' }

    method default-styles(:$locale!, :@items, :%icons) {
        my $max-icon = 0 max %icons.values.map({ $locale.width($_) }).max;
        my $spacing  = 2 + ?$max-icon;

        %( min-h => @items.elems,
           min-w => $spacing + $max-icon +
                    (0 max @items.map({ $locale.width(.<title>) }).max) )
    }
}


#| A multi-line single-select menu
class Terminal::Widgets::Input::Menu
   is Terminal::Widgets::Widget
 does Terminal::Widgets::Input {
    has UInt:D $.current  = 0;
    has UInt:D $.selected = 0;
    has UInt:D $.top-item = 0;
    has        $.items;
    has        %.icons;
    has        %!hotkey;

    method layout-class() { Terminal::Widgets::Layout::Menu }

    #| Do basic input TWEAK, then compute hotkey hash
    submethod TWEAK() {
        self.Terminal::Widgets::Input::TWEAK;
        for $!items.kv -> $i, $item {
            %!hotkey{$_} = $i for ($item<hotkeys> // []).words;
        }
    }

    # Menu-specific gist flags
    method gist-flags() {
        |self.Terminal::Widgets::Input::gist-flags,
        'items:'    ~ $!items.elems,
        'top-item:' ~ $!top-item,
        'current:'  ~ $!current,
        'selected:' ~ $!selected,
        'hotkeys:'  ~ %!hotkey.elems,
    }

    #| Draw content area
    method draw-content() {
        my ($x, $y, $w, $h) = self.content-rect;
        my $terminal   = self.terminal;
        my $locale     = $terminal.locale;
        my $base-color = self.current-color;
        my $highlight  = $.colorset.highlight;

        for ^$h {
            last if $!items.end < my $i = $.top-item + $_;

            my $item      = $!items[$i];
            my $icon      = ($item<id> && %.icons{$item<id>}) // '';
            my $title     = $terminal.sanitize-text($locale.plain-text($item<title>));
            my $mark      = $i == $!current ?? '>' !! ' ';
            my $formatted = span-tree($mark, ($icon ~ ' ' if $icon), $title, ' ');
            my $extra     = 0 max $w - $locale.width($formatted);
            my $padding   = pad-span($extra);
            my $color     = $i == $!selected ?? $highlight
                                             !! $item<color> // $base-color;
            my @spans     = $locale.render(span-tree($formatted, $padding, :$color));
            self.draw-line-spans($x, $y + $_, $w, @spans);
        }
    }

    #| Scroll to keep the current element visible
    method auto-scroll() {
        my $h         = $.h - $.layout.computed.height-correction;
        my $last-top  = 0 max ($!items.elems - $h);
        $!top-item min= $!current min $last-top;
        $!top-item max= $!current + 1 - $h;
    }

    #| Set an item as current and make sure it is visible
    method set-current(Int:D $current) {
        if 0 <= $current <= @.items.end {
            $!current = $current;
            self.set-hint(@.items[$!current]<hint> // '');
            self.auto-scroll;
        }
    }

    #| Set an item as selected and make sure it is visible
    method set-selected(Int:D $selected) {
        if 0 <= $selected <= @.items.end {
            $!current = $!selected = $selected;
            self.set-hint(@.items[$!current]<hint> // '');
            self.auto-scroll;
        }
    }

    #| Process a select event
    method select(UInt:D $i = $!current, Bool:D :$print = True) {
        return unless $i <= @.items.end;
        self.set-selected($i);

        $!active = True;
        self.refresh-value(:$print);

        $_(self) with &.process-input;

        $!active = False;
        self.refresh-value(:$print);
    }

    #| Process a prev-item event
    method prev-item(Bool:D :$print = True) {
        self.set-current($!current - 1);
        self.refresh-value(:$print);
    }

    #| Process a next-item event
    method next-item(Bool:D :$print = True) {
        self.set-current($!current + 1);
        self.refresh-value(:$print);
    }

    #| Handle keyboard events
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my constant %keymap =
            ' '          => 'select',
            Ctrl-M       => 'select',  # CR/Enter
            KeypadEnter  => 'select',

            CursorUp     => 'prev-item',
            CursorDown   => 'next-item',

            Ctrl-I       => 'focus-next',    # Tab
            ShiftTab     => 'focus-prev',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            # Allow navigation always, but only allow selection if enabled
            when 'select'     { self.select if $.enabled }
            when 'prev-item'  { self.prev-item }
            when 'next-item'  { self.next-item }
            when 'focus-next' { self.focus-next }
            when 'focus-next' { self.focus-prev }
        }
        orwith %!hotkey{$keyname} {
            self.select($_)
        }
    }

    #| Handle mouse events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Take focus even if clicked on framing instead of content area
        self.toplevel.focus-on(self);

        # Only allow selection if enabled and within content area
        if $.enabled {
            my ($x, $y, $w, $h) = $event.relative-to-content-area(self);
            self.select($.top-item + $y) if 0 <= $x < $w && 0 <= $y < $h;
        }

        # Refresh even if outside content area because of focus state change
        self.full-refresh;
    }

    #| Handle LayoutBuilt event by updating hint and scrolling
    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, AtTarget) {
        self.set-selected($!selected);
    }
}


# Register Menu as a buildable widget type
Terminal::Widgets::Input::Menu.register;
