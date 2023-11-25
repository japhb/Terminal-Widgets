# ABSTRACT: Single line text input

use Terminal::LineEditor::DuospaceInput;
use Terminal::LineEditor::RawTerminalInput;
use Text::MiscUtils::Layout;

use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::Events;
use Terminal::Widgets::Input;


#| Single-line text entry field with history tracking and mappable keys
class Terminal::Widgets::Input::Text
 does Terminal::Widgets::Input
 does Terminal::LineEditor::HistoryTracking
 does Terminal::LineEditor::KeyMappable {
    has $.input-class = Terminal::LineEditor::ScrollingSingleLineInput::ANSI;
    has $.input-field;

    has &.get-completions;

    has      $!completions;
    has UInt $!completion-index;

    has Bool:D $!literal-mode    = False;
    has Str:D  $.prompt-string   = '>';
    has Str:D  $.disabled-string = '';

    # Text input specific gist flags
    method gist-flags() {
        |self.Terminal::Widgets::Input::gist-flags,
        ('literal-mode' if $!literal-mode),
        ("prompt:'$!prompt-string'" if $!prompt-string),
        ("disabled:'$!disabled-string'" if $!disabled-string),
        ("completion:$!completion-index/$!completions.elems()" if $!completions),
        ("contents:'$!input-field.buffer.contents()'" if $!input-field);
    }

    #| Set $!input-field, with both compile-time and runtime type checks
    method set-input-field(Terminal::LineEditor::ScrollingSingleLineInput:D $new-field) {
        die "New input-field is not a $.input-class"
            unless $new-field ~~ $.input-class;
        $!input-field = $new-field;
    }

    #| Set current prompt-string
    method set-prompt(Str:D $!prompt-string) {
        self.full-refresh
    }

    #| Completely refresh input, including possibly toggling enabled state
    method full-refresh(Str:D $content = $.input-field.?buffer.contents // '',
                        Bool:D :$print = True) {
        if $.enabled {
            # Determine new field metrics
            my $layout        = self.layout.computed;
            my $prompt-width  = duospace-width($.prompt-string);
            my $field-start   = $prompt-width
                              + $layout.left-correction;
            my $display-width = $.w - $prompt-width
                              - $layout.width-correction;

            # Create a new input field using the new metrics
            # XXXX: Should we support masked inputs?
            my $caps = self.terminal.caps;
            self.set-input-field($.input-class.new(:$display-width, :$field-start, :$caps));

            # Insert initial content if any and refresh input field
            self.do-edit('insert-string', $content, :force-refresh);
        }
        else {
            self.show-disabled(:$print);
        }
    }

    #| Display input disabled state
    method show-disabled(Bool:D :$print = True) {
        my $layout = self.layout.computed;
        my $x      = $layout.left-correction;
        my $y      = $layout.top-correction;
        my $w      = $.w - $layout.width-correction;

        self.clear-frame;
        self.draw-framing;

        $.grid.set-span-text($x, $y, $.disabled-string);
        $.grid.set-span-color($x, $x + $w - 1, $y, self.current-color);
        self.composite(:$print);
    }

    #| Do edit in current input field, then print and flush the full refresh string
    method do-edit($action, $insert?, Bool:D :$force-refresh = False,
                   Bool:D :$print = True) {
        my $edited = $insert.defined ?? $.input-field.edit-insert-string($insert)
                                     !! $.input-field."edit-$action"();

        self.refresh-input-field($force-refresh || $edited);
        self.composite(:$print);
    }

    #| Refresh widget in input field mode
    method refresh-input-field(Bool:D $edited = True) {
        my $layout  = self.layout.computed;
        my $x       = $layout.left-correction;
        my $y       = $layout.top-correction;

        my $color   = self.current-color;
        my $refresh = $.input-field.render(:$edited);
        my $start   = $.input-field.field-start;
        my $pos     = $start
                    + $.input-field.left-mark-width
                    + $.input-field.scroll-to-insert-width;

        self.clear-frame;
        self.draw-framing;

        $.grid.set-span($x,     $y, $.prompt-string, "$color bold");
        $.grid.set-span($start, $y, $refresh, $color);
        $.grid.set-span-color($pos, $pos, $y, "$color inverse");
    }

    #| Fetch completions based on current buffer contents and cursor pos
    method fetch-completions() {
        with &.get-completions {
            my $contents = $.input-field.buffer.contents;
            my $pos      = $.input-field.insert-cursor.pos;
            $_(:$contents, :$pos, :input(self));
        }
        else { Empty }
    }

    #| Edit with next available completion
    method do-complete(Bool:D :$print = True) {
        if $!completions {
            # Undo previous completion if any
            my $max = $!completions.elems;
            self.do-edit('undo') if $!completion-index < $max;

            # Revert to non-completion if at end
            return if ++$!completion-index == $max;

            $!completion-index = 0 if $!completion-index > $max;
        }
        else {
            $!completions      = self.fetch-completions or return;
            $!completion-index = 0;
        }

        my $edited = $.input-field.buffer.replace(0, $.input-field.insert-cursor.pos,
                                                  $!completions[$!completion-index]);
        self.refresh-input-field($edited);
        self.composite(:$print);
    }

    #| If not currently completing, all other actions should reset-completions
    method reset-completions() {
        $!completions      = Nil;
        $!completion-index = Nil;
    }

    #| Dispatch a key event when enabled for editing
    multi method handle-event(Terminal::Widgets::Events::KeyboardEvent:D
                              $event where *.key.defined, AtTarget) {
        my $raw-key = $event.key;
        if $!literal-mode {
            my $string = $raw-key ~~ Str ?? $raw-key !! ~($raw-key.value);
            self.do-edit('insert-string', $string);
            $!literal-mode = False;
        }
        else {
            my $key = self.decode-keyname($raw-key);
            if !$key {
                self.do-edit('insert-string', $raw-key);
                self.reset-completions;
            }
            orwith $key && %.keymap{$key} {
                when 'complete'        { self.do-complete }
                self.reset-completions;

                when 'literal-next'    { $!literal-mode = True }
                # XXXX: Disable history when in masked (password/secret) mode
                when 'history-start'   { self.do-history-start }
                when 'history-prev'    { self.do-history-prev  }
                when 'history-next'    { self.do-history-next  }
                when 'history-end'     { self.do-history-end   }

                # Suspends program when self.suspend is called, dropping back to shell.
                # When the user resumes, the code picks up at the end of self.suspend.
                when 'suspend'         { self.suspend;
                                         $.input-field.force-pos-to-start;
                                         self.do-edit('insert-string', ''); }

                # Core key bindings: finishing, aborting, generic edits
                when 'finish'          { self.finish-entry }
                when 'abort-input'     { self.abort-entry  }
                when 'abort-or-delete' { $.input-field.buffer.contents
                                         ?? self.do-edit('delete-char-forward')
                                         !! self.abort-entry }
                default                { self.do-edit($_) }
            }
        }
    }

    #| Handle mouse events
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        self.toplevel.focus-on(self);
        # XXXX: Move cursor?
    }

    #| Abort entry in progress
    method abort-entry() {
        self.reset-entry-state;
    }

    #| Finish entry in progress
    method finish-entry() {
        my $input = $.input-field.buffer.contents.trim;
        self.reset-entry-state;

        self.add-history($input) if $input;
        $_($input) with &.process-input;
    }

    #| Clear entry state, clear input field, and refresh
    method reset-entry-state() {
        $!literal-mode = False;
        $.unfinished-entry = '';
        self.full-refresh('');
    }

    # History helpers
    method do-history-start() {
        return unless @.history && $.history-cursor;

        $.unfinished-entry = $.input-field.buffer.contents
            if self.history-cursor-at-end;

        self.jump-to-history-start;
        self.full-refresh(self.history-entry);
    }

    method do-history-prev() {
        return unless @.history && $.history-cursor;

        $.unfinished-entry = $.input-field.buffer.contents
            if self.history-cursor-at-end;

        self.history-prev;
        self.full-refresh(self.history-entry);
    }

    method do-history-next() {
        return if self.history-cursor-at-end;

        self.history-next;
        self.full-refresh(self.history-entry);
    }

    method do-history-end() {
        return if self.history-cursor-at-end;

        self.jump-to-history-end;
        self.full-refresh(self.history-entry);
    }
}
