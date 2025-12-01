# ABSTRACT: Demonstrate effects of ColorSets and widget theme attributes

use Terminal::Widgets::Events;
use Terminal::Widgets::Simple;
use Terminal::Widgets::TextContent;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class ColorSetUI is TopLevel {
    method initial-layout($builder, $width, $height) {
        my $terminal = $.terminal;
        my $locale   = $terminal.locale;
        my $theme    = $terminal.color-theme.name;
        my @variants = $terminal.color-theme.variants.keys.sort;
        my @items    = @variants.map({ %( id => $_, title => $_ ) });
        my %top-margin = %( margin-width => (1, 0, 0, 0) );
        my $header   = 'bold yellow underline';

        with $builder {
            .node(
                .node(:vertical, style => %( :minimize-w ),
                      .plain-text(id => 'theme-label', style => %( set-h => 1 ),
                                  text => 'Theme:'),
                      .plain-text(id => 'theme', text => $locale.plain-text($theme),
                                  style => %( set-h => 1,
                                              margin-width => [ 0, 0, 1, 1] )),
                      .plain-text(id => 'menu-label', style => %( set-h => 1 ),
                                  text => 'Theme Variant:'),
                      .menu(    id => 'variant', :@items,
                                process-input => { self.show-variant }),
                      .checkbox(id => 'show-active', label => 'Show Active Flash',
                                process-input => { self.show-active-flash },
                                style => %top-margin, state => True),
                      .button(  id => 'quit', label => 'Quit',
                                process-input => { $.terminal.quit },
                                style => %top-margin),
                     ),
                .divider(line-style => 'light1', style => %( set-w => 1)),
                .node(:vertical,
                      .widget(:vertical,  id => 'samples', style => %( :minimize-h ),
                              .plain-text(id => 'text',   text  => 'Just plain text',
                                          extra-theme-states => %( :text )),
                              .plain-text(id => 'hint',   text  => 'Context-sensitive hint',
                                          extra-theme-states => %( :text, :hint )),
                              .plain-text(id => 'link',   text  => 'Clickable link',
                                          extra-theme-states => %( :text, :link )),
                              .button(    id => 'input',  label => 'Input widget'),
                              .button(    id => 'disabled', label => 'Disabled widget',
                                          :!enabled),
                              .text-input(id => 'prompt', prompt-string => 'Prompt >'),
                              .text-input(id => 'error',  prompt-string => 'Error >',
                                          error => 'Error state set'),
                              .text-input(id => 'disabled-text', prompt-string => '>',
                                          disabled-string => 'Disabled text input',
                                          :!enabled),
                             ),
                      .node(),
                     ),
            )
        }
    }

    method set-variant() {
        # Determine selected ColorSet
        my $menu     = %.by-id<variant>;
        my $item     = $menu.items[$menu.selected];
        my $variant  = $item<id>;
        my $colorset = $.terminal.color-theme.variants{$variant};

        # Refresh samples with new ColorSet
        my $samples  = %.by-id<samples>;
        for $samples.children {
            .set-colorset($colorset);
            .full-refresh;
        }
    }

    method show-variant() {
        self.set-variant;
        self.redraw-all;
    }

    method set-active-flash() {
        # Select whether input flash is active
        my $show = %.by-id<show-active>.state;
        $.terminal.ui-prefs<input-activation-flash> = $show;

        # Refresh samples with new UI pref
        my $samples  = %.by-id<samples>;
        for $samples.children {
            .full-refresh;
        }
    }

    method show-active-flash() {
        self.set-active-flash;
        self.redraw-all;
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        self.set-active-flash;
        self.set-variant;
    }
}


sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the demo screen
    App.new.boot-to-screen('colorsets', ColorSetUI, title => 'ColorSet Demo Example');
}
