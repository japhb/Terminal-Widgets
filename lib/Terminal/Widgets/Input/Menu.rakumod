# ABSTRACT: Simple single-selection menu

use Text::MiscUtils::Layout;

use Terminal::Widgets::Events;
use Terminal::Widgets::Input;


class Terminal::Widgets::Input::Menu
 does Terminal::Widgets::Input {
    has UInt:D $.selected = 0;
    has UInt:D $.top-item = 0;
    has        $.hint-target;
    has        $.items;
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
        "items:$!items.elems()",
        "top-item:$!top-item",
        "selected:$!selected",
        "hotkeys:%!hotkey.elems()",
        "hint-target:$!hint-target.gist()"
    }

    #| Refresh the whole input
    method full-refresh(Bool:D :$print = True) {
        my $layout     = self.layout.computed;
        my $x          = $layout.left-correction;
        my $y          = $layout.top-correction;
        my $w          = $.w - $layout.width-correction;
        my $h          = $.h - $layout.height-correction;
        my $base-color = self.current-color;

        self.set-selected($!selected);
        self.clear-frame;
        self.draw-framing;

        for ^$h {
            last if $!items.end < my $i = $.top-item + $_;

            my $item      = $!items[$i];
            my $title     = $item<title>;
            my $extra     = 1 max $w - 1 - duospace-width($title);
            my $formatted = " $title" ~ ' ' x $extra;
            my $color     = $i == $!selected ?? %.color<highlight>
                                             !! $item<color> // $base-color;
            $.grid.set-span($x, $y + $_, $formatted, $color);
        }

        self.composite(:$print);
    }

    #| Set the hint
    method set-hint(Str:D $hint) {
        my $target = $.hint-target;
           $target = self.toplevel.by-id{$target} if $target ~~ Str:D;

        $target.?set-text($hint);
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
            when 'select'     { self.select }
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
        self.toplevel.focus-on(self);
        self.select($.top-item + $event.relative-to(self)[1]);
    }
}
