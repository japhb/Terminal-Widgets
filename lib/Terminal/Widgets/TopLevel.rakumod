# ABSTRACT: A top-level (full-screen) widget

use Terminal::Widgets::Widget;
use Terminal::Widgets::Events;
use Terminal::Widgets::Layout;


#| A top-level full-screen widget with modal access to its controlling terminal
role Terminal::Widgets::TopLevel
  is Terminal::Widgets::Widget
does Terminal::Widgets::Layout::WidgetBuilding {
    has                           $.terminal is required;
    has Terminal::Widgets::Widget $.focused-widget;
    has Str                       $.title;

    #| Check if the Terminal believes this is its current TopLevel
    method is-current-toplevel(--> Bool:D) {
        self === $.terminal.current-toplevel
    }

    #| Send an event requesting that a target widget takes focus,
    #| and do necessary unfocus/refocus redraws
    method focus-on(Terminal::Widgets::Widget:D $target,
                    Bool:D :$redraw = True) {
        # Determine if focus is "really" changing
        my $prev    = $!focused-widget;
        my $changed = $prev && $prev !=== $target;

        # Redraw previous widget as unfocused
        if $redraw && $changed {
            $!focused-widget = Nil;
            my $frame-info = Terminal::Widgets::FrameInfo.new;
            $prev.do-frame($frame-info);
            $prev.composite;
        }

        # Actually send the TakeFocus event (sends even if !$changed because
        # this could have been triggered by a reparenting operation, so the
        # widget tree needs focused-child fixups)
        self.process-event(Terminal::Widgets::Events::TakeFocus.new(:$target));
        $!focused-widget = $target;

        # Draw target widget as focused
        if $redraw {
            my $frame-info = Terminal::Widgets::FrameInfo.new;
            $target.do-frame($frame-info);
            $target.composite;
        }
    }

    #| Redraw entire widget tree
    method redraw-all() {
        my $frame-info = Terminal::Widgets::FrameInfo.new;
        self.do-frame($frame-info);
    }

    # XXXX: Allow terminal to be disconnected or switched?
    # XXXX: Does disconnect imply recursive destroy?
}
