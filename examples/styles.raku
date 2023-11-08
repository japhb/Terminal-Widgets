# ABSTRACT: Simple style and layout example based on Terminal::Widgets::Simple

use Terminal::Widgets::Simple;
use Terminal::Widgets::Utils::Color;


#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class StyleUI is TopLevel {
    method initial-layout($builder, $width, $height) {
        # Build up a style table that will be the main content
        my $table = do with $builder {
            # Lay out columns horizontally with styled dividers between
            .node(
                # Column 0: basic attributes
                .node(:vertical,
                      .plain-text(text  => 'bold',      color => 'bold'),
                      .plain-text(text  => 'italic',    color => 'italic'),
                      .plain-text(text  => 'inverse',   color => 'inverse'),
                      .plain-text(text  => 'underline', color => 'underline'),
                      .plain-text(text  => 'all of the above',
                                  color => 'bold italic inverse underline'),
                ),

                # First divider: light dashed
                .divider(line-style => 'light2', style => %(set-w => 1)),

                # Column 1: paletted colors using historical names
                .node(:vertical,
                      .plain-text(text  => 'red',        color => 'red'),
                      .plain-text(text  => 'on_blue',    color => 'on_blue'),
                      .plain-text(text  => 'bold black', color => 'bold black'),
                      .plain-text(text  => 'bold white on_red',
                                  color => 'bold white on_red'),
                      .plain-text(text  => 'underline yellow',
                                  color => 'underline yellow'),
                ),

                # Second divider: heavy dotted
                .divider(line-style => 'heavy4', style => %(set-w => 1)),

                # Column 2: 8-bit colors
                .node(:vertical,
                      # Directly using xterm-256color numeric ids
                      .plain-text(text  => 'dark red on mid-grey',
                                  color => '52 on_243'),

                      # Using rgb-color() helper
                      .plain-text(text  => 'pale yellow',
                                  color => rgb-color(1, 1, .7)),

                      # Using gray-color() helper
                      .plain-text(text  => '3/4 gray',
                                  color => gray-color(3/4)),

                      # Using luminosity conversion (orangey color)
                      .plain-text(text  => 'luma(peach)',
                                  color => gray-color(rgb-luma(1, .796, .643))),

                      # Using luminosity conversion (bluish color)
                      .plain-text(text  => 'luma(aquamarine)',
                                  color => gray-color(rgb-luma(0, 164/255, 203/255))),
                ),

                # Third divider: doubled
                .divider(line-style => 'double', style => %(set-w => 1)),

                # Column 3: 24-bit colors
                .node(:vertical,
                      .plain-text(text  => 'fire brick', color => '178,34,34'),
                      .plain-text(text  => 'sweet corn', color => '251,236,93'),
                      .plain-text(text  => 'almond on slate gray',
                                  color => '239,222,205 on_112,128,144'),
                      .plain-text(text  => 'peach',      color => '255,203,164'),
                      .plain-text(text  => 'aquamarine', color => '0,164,203'),
                ),
            )
        };

        # Center the style table on the screen using a simple centering trick:
        # an outer node (horizontal or vertical) containing just 3 children --
        # two empty space-filling nodes surrounding a minimized inner node
        with $builder {
            # Outer container node; centers middle node horizontally using
            # default horizontal layout direction for all three children
            .node(
                # Empty for left space
                .node(),
                # Width-minimized center content node; centers its own content
                # vertically by specifying vertical layout and using same trick
                .node(:vertical, style => %(:minimize-w),
                      # Empty for top space
                      .node(),
                      # Height-minimized node containing content
                      .node(:vertical, style => %(:minimize-h),
                            # Show the style table
                            $table,

                            # Add a horizontal divider and a quit button
                            .divider(line-style => 'light1', style => %(set-h => 1)),
                            .button(label => 'Quit',
                                    process-input => { $.terminal.quit }),
                           ),
                      # Empty for bottom space
                      .node(),
                     ),
                # Empty for right space
                .node(),
            )
        }
    }
}


sub MAIN() {
    # Boot a Terminal::Widgets::App and jump right to the style demo
    App.new.boot-to-screen('styles', StyleUI, title => 'Text Style Example');
}
