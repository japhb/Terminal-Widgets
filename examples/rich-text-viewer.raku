# ABSTRACT: Demonstrate the rich text widget

use Terminal::Capabilities;

use Terminal::Widgets::Simple;
use Terminal::Widgets::Events;
use Terminal::Widgets::TextContent;
use Terminal::Widgets::WrappableBuffer;
use Terminal::Widgets::Viewer::RichText;

constant Uni1 = Terminal::Capabilities::SymbolSet::Uni1;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class RichTextViewerDemo is TopLevel {
    has $!text = "    😂😂😂😂😂😂😂😂 Some not so short demo text.  This text is deliberately long, so one can test line wrapping without having to type in so much text first.  So here is some more to really hit home and be sure that we definitely have enough text to fill a line even on very wide screen displays and very small fonts.  We'll see if someone speaks up and says that this text is not long enough on their setup to test line wrapping.  Here are some more duowidth chars: 😂😂😂😂😂😂😂😂😂😂😂😂 \n0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890";

    has $!spans = span-tree(
        string-span(' Span 1 ', color => 'on_red'),
        string-span('  Span 2  ', color => 'on_green'),
        string-span('   Span 3   ', color => 'on_blue'),
        string-span('    Span 4    ', color => 'on_yellow'),
        string-span('     Span 5     ', color => 'on_cyan'),
        string-span('      Span 6      ', color => 'on_magenta'),
    );

    has $!list = string-span("\n\nHat,\n  scarf,   gloves,  \njacket, boots\n\n",
                             color => 'inverse');


    method initial-layout($builder, $width, $height) {
        my sub wrap-args($wrap-mode) {
            my $label = ~$wrap-mode .subst(/(<.lower>)(<.upper>)/, { "$0 $1" }, :g);
            my $id    = $label.subst(' ', '-', :g).lc;
            my %args  = :$label, :$id, group => 'wrap-mode',
                        process-input => { self.update-wrap-style(:$wrap-mode) if .state };
        }

        my sub squash-args($squash-mode) {
            my $label = ~$squash-mode .subst(/(<.lower>)(<.upper>)/, { "$0 $1" }, :g);
            my $id    = $label.subst(' ', '-', :g).lc;
            my %args  = :$label, :$id, group => 'squash-mode',
                        process-input => { self.update-wrap-style(:$squash-mode) if .state };
        }

        with $builder {
            .node(style => %( :minimize-h ),
                  .node(:vertical,
                        style => %( :minimize-w, margin-width => [0, 4, 0, 0]),
                        .radio-button(|wrap-args(NoWrap), state => True),
                        .radio-button(|wrap-args(GraphemeWrap)),
                        .radio-button(|wrap-args(GraphemeFill)),
                        .radio-button(|wrap-args(WordWrap)),
                        .radio-button(|wrap-args(WordFill)),
                       ),
                  .node(:vertical,
                        style => %( :minimize-w, margin-width => [0, 4, 0, 0]),
                        .radio-button(|squash-args(NoSquash), state => True),
                        .radio-button(|squash-args(PartialSquash)),
                        .radio-button(|squash-args(FullSquash)),
                        .checkbox(label => 'Cross-line Cursor Wrap',
                                  id    => 'cross-line-cursor',
                                  state => True,
                                  process-input => {
                                      self.update-wrap-style:
                                          wrap-cursor-between-lines => .state;
                                  }),
                        .checkbox(label => 'Highlight to Edge',
                                  id    => 'highlight-to-edge',
                                  state => False,
                                  process-input => {
                                      self.update-highlight-style:
                                          highlight-lines-to-content-edge => .state;
                                  }),
                       ),
                  .node(:vertical,
                        .text-input(style => %( margin-width => [0, 0, 3, 0] ),
                                    :!clear-on-finish,
                                    prompt-string => 'Wrap Prefix >',
                                    process-input => { self.update-wrap-style:
                                                       wrapped-line-prefix => $_ }),
                        .push-right(style => %( :minimize-w ),
                                    .button(label => 'Quit',
                                            process-input => { $.terminal.quit }),
                                   ),
                       ),
                 ),
            .divider(line-style => 'light1', style => %(set-h => 1)),
            .node(
                .with-scrollbars(style => %(:minimize-w),
                    .rich-text-viewer(id => 'buffer', style => %(set-w => 50),
                                      process-click => -> $span, $x, $y {
                                          self.process-click($span, $x, $y);
                                      }),
                ),
                .with-scrollbars(.log-viewer(id => 'click-log')),
            ),
        }
    }

    method process-click($span, $x, $y) {
        my $click-log = %.by-id<click-log>;
        if $span {
            my $drop   = 'Terminal::Widgets::TextContent::';
            my $entry  = "Click @ $x,$y on span:\n";
            my %info  := span-info($span);
            my $max    = %info.keys.map(*.chars).max;
            my $wide   = $click-log.w > $max + 30;
            my $format = $wide ?? "  %-{$max}s   %s\n" !! "%s: %s, ";

            for span-info($span).sort({ .key.contains('span'), .key}) {
                my $value = .value ~~ RenderSpan|SemanticText
                             ?? .value.WHICH.Str
                             !! .value.raku;

                $entry ~= sprintf $format, .key,
                                  $value.subst($drop, '', :g);
            }

            $click-log.add-entry($entry.subst(/', ' $/, '') ~ "\n");
        }
        else {
            $click-log.add-entry("Click @ $x,$y (no matching span)\n\n");
        }
        $click-log.refresh-for-scroll;
    }

    method update-wrap-style(|c) {
        with %.by-id<buffer> {
            .set-wrap-style(.wrap-style.clone: |c);
            .update-scroll-maxes;
            .refresh-for-scroll(:force);
        }
    }

    method update-highlight-style(*%settings) {
        with %.by-id<buffer> {
            my $hl-to-edge = %settings<highlight-lines-to-content-edge>;
            .highlight-lines-to-content-edge = $hl-to-edge if $hl-to-edge.defined;

            .full-refresh;
        }
    }

    multi method handle-event(Terminal::Widgets::Events::LayoutBuilt:D, BubbleUp) {
        with %.by-id<click-log> {
            my $marker = $.terminal.caps.symbol-set >= Uni1 ?? '↳ ' !! '> ';
            my $wrapped-line-prefix = string-span($marker, color => 'faint');
            .set-wrap-style(.wrap-style.clone(wrap-mode => GraphemeWrap,
                                              :$wrapped-line-prefix));
        }
        with %.by-id<buffer> {
            if .empty {
                .highlight-mode = SoftLineHighlight;
                .cursor-mode    = GraphemeHighlight;

                .insert-line-group($!spans);
                .insert-line-group($!list);
                .insert-line-group($!text);
                .update-scroll-maxes;
            }
        }
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the form screen
    App.new.boot-to-screen('form', RichTextViewerDemo,
                           title => 'RichText Viewer Example');
}
