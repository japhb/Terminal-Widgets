# ABSTRACT: Simple single-selection menu

use Terminal::Widgets::Events;
use Terminal::Widgets::Input;


class Terminal::Widgets::Input::Menu
 does Terminal::Widgets::Input {
    has UInt:D $.selected = 0;
    has UInt:D $.top-item = 0;
    has        $.items;
    has        %.icons;
    has        %!hotkey;

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
        'items:' ~ $!items.elems,
        'top-item:' ~ $!top-item,
        'selected:' ~ $!selected,
        'hotkeys:' ~ %!hotkey.elems,
    }

    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        self.clear-frame;
        self.draw-frame;
        self.composite(:$print);
    }

    #| Draw framing and full input
    method draw-frame() {
        my $layout     = self.layout.computed;
        my $locale     = self.terminal.locale;
        my $x          = $layout.left-correction;
        my $y          = $layout.top-correction;
        my $w          = $.w - $layout.width-correction;
        my $h          = $.h - $layout.height-correction;
        my $base-color = self.current-color;
        my $highlight  = $.colorset.highlight;

        self.draw-framing;

        for ^$h {
            last if $!items.end < my $i = $.top-item + $_;

            my $item      = $!items[$i];
            my $icon      = ($item<id> && %.icons{$item<id>}) // '';
            my $title     = $locale.translate($item<title>);
            my $formatted = ' ' ~ ("$icon " if $icon) ~ $title ~ ' ';
            my $extra     = 0 max $w - $locale.width($formatted);
            my $padding   = ' ' x $extra;
            my $color     = $i == $!selected ?? $highlight
                                             !! $item<color> // $base-color;
            $.grid.set-span($x, $y + $_, $formatted ~ $padding, $color);
        }
    }

    #| Scroll to keep the selected element visible
    method auto-scroll() {
        my $h         = $.h - $.layout.computed.height-correction;
        my $last-top  = 0 max ($!items.elems - $h);
        $!top-item min= $!selected min $last-top;
        $!top-item max= $!selected + 1 - $h;
    }

    #| Set an item as selected and make sure it is visible
    method set-selected(Int:D $selected) {
        if 0 <= $selected <= @.items.end {
            $!selected = $selected;
            self.set-hint(@.items[$!selected]<hint> // '');
            self.auto-scroll;
        }
    }

    #| Process a select event
    method select(UInt $i?, Bool:D :$print = True) {
        if $i.defined {
            return unless 0 <= $i <= @.items.end;
            self.set-selected($i);
        }

        $!active = True;
        self.refresh-value(:$print);

        $_(self) with &.process-input;

        $!active = False;
        self.refresh-value(:$print);
    }

    #| Process a prev-item event
    method prev-item(Bool:D :$print = True) {
        self.set-selected($!selected - 1);
        self.refresh-value(:$print);
    }

    #| Process a next-item event
    method next-item(Bool:D :$print = True) {
        self.set-selected($!selected + 1);
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

            Ctrl-I       => 'next-input',    # Tab
            ShiftTab     => 'prev-input',    # Shift-Tab is weird and special
            ;

        my $keyname = $event.keyname;
        with %keymap{$keyname} {
            # Allow navigation always, but only allow selection if enabled
            when 'select'     { self.select if $.enabled }
            when 'prev-item'  { self.prev-item }
            when 'next-item'  { self.next-item }
            when 'next-input' { self.focus-next-input }
            when 'prev-input' { self.focus-prev-input }
        }
        orwith %!hotkey{$keyname} {
            self.select($_)
        }
    }

    #| Handle mouse events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Always focus on click, but only allow selection if enabled
        self.toplevel.focus-on(self);
        self.select($.top-item + $event.relative-to(self)[1]) if $.enabled;
    }

    #| Handle LayoutBuilt event by updating hint and scrolling
    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, AtTarget) {
        self.set-selected($!selected);
    }
}
