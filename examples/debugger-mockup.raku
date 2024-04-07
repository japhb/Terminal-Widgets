# ABSTRACT: Debugger UI mockup from https://github.com/japhb/Terminal-Widgets/issues/11

# NOTE: This example is purely a mockup for issue #11 to assist discussion and
#       iteration on T-W tooling that will make it easier to implement.


use Terminal::Widgets::Events;
use Terminal::Widgets::Simple;
use Terminal::Widgets::SpanStyle;
use Terminal::Widgets::I18N::Translation;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class DebuggerMockup is TopLevel {
    method initial-layout($builder, $width, $height) {
        my %button-style = padding-width => (0, 1, 0, 0),;

        with $builder {
            # Header
            .plain-text(id    => 'note', color => 'bold red',
                        style => %( set-h => 1, margin-width => (0, 0, 1, 0), ),
                        text  => 'ONLY A VISUAL MOCKUP, CURRENTLY NOT FUNCTIONAL'),
            .plain-text(id   => 'breadcrumbs', color => 'cyan',
                        style => %( set-h => 1, ),
                        text => '_T_hread 1 > _F_rame 47 > My/ClassyClass.rakumod:7'),

            # Viewer panes
            .node(
                # Left pane
                .node(:vertical,
                      .plain-text(id => 'left-title', color => 'bold yellow',
                                  style => %( set-h => 1, ),
                                  # XXXX: Translations for PlainText widgets
                                  text => 'Source'),
                      .node(
                          .log-viewer(id => 'source'),
                          .vscroll(scroll-target => 'source'),
                      ),
                      .node(
                          .hscroll(scroll-target => 'source'),
                          .spacer(style => %(set-w => 1, set-h => 1)),
                      ),
                ),

                .divider(line-style => 'light1', style => %( set-w => 1, )),

                # Right pane
                .node(:vertical,
                      .plain-text(id => 'right-title', color => 'bold yellow',
                                  style => %( set-h => 1, ),
                                  # XXXX: Translations for PlainText widgets
                                  text => 'Locals'),
                      .node(
                          .log-viewer(id => 'inspector'),
                          .vscroll(scroll-target => 'inspector'),
                      ),
                      .node(
                          .hscroll(scroll-target => 'inspector'),
                          .spacer(style => %(set-w => 1, set-h => 1)),
                      ),
                ),
            ),

            # Footer
            .node(style => %( :minimize-h, ),
                  # Button bar
                  .node(style => %( :minimize-w, ),
                        .button(style => %button-style, label => ¿'Source',
                                process-input => { $.terminal.quit }),
                        .button(style => %button-style, label => ¿'Locals',
                                process-input => { $.terminal.quit }),
                        .button(style => %button-style, label => ¿'REPL',
                                process-input => { $.terminal.quit }),
                        .button(style => %button-style, label => ¿'Console',
                                process-input => { $.terminal.quit }),
                        # XXXX: Fix up translation of Breakpoints with interpolant
                        .button(style => %button-style, label => 'Breakpoints' ~ ' (7)',
                                process-input => { $.terminal.quit }),
                        .button(style => %button-style, label => ¿'Help',
                                process-input => { $.terminal.quit }),
                        .button(style => %button-style, label => ¿'Quit',
                                process-input => { $.terminal.quit }),
                       ),
                  .spacer,
            ),
        }
    }

    #| Handle LayoutBuilt event by filling left and right panes with mockup text
    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        my $source    = %.by-id<source>;
        my $inspector = %.by-id<inspector>;

        my @code-lines = q:to/SOURCE/.lines;
            # Defining My::ClassyClass ...
            # It's such a classy class,
            # I can't even handle it,
            # I need to say yay!
            class My::ClassyClass {
                method do() {
                    say 'Yay!';
                }
            }
            SOURCE

        my $max-lineno-width = @code-lines.elems.chars;
        for @code-lines.kv -> $i, $line {
            my $lineno      = $i + 1;
            my $lineno-span = $lineno == 7 ?? span('bold yellow', $lineno ~ '>')
                                           !! $lineno ~ ' ';
            $source.add-entry(span-tree('',
                                        ' ' x ($max-lineno-width - $lineno.chars),
                                        $lineno-span, '│', $line));
        }

        $inspector.add-entry: q:to/INSPECTOR/;
            > $foo (Str)  = iea
            > $!bar (Int) = 5
            > @baz (List) = 1, 3, 5, 7, ...
            ...
            INSPECTOR

        $source.full-refresh;
        $inspector.full-refresh;
    }
}


sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('debugger', DebuggerMockup, title => 'Debugger Mockup');
}
