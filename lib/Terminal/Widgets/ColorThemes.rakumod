# ABSTRACT: Premade ColorTheme palettes

use Terminal::Widgets::I18N::Translation;
use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::ColorTheme;


### 'attr' variants: ColorSets with italic/inverse/underline attributes enabled

constant $default-attrmono = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'italic',
                             link      => 'bold underline',
                             input     => '',
                             prompt    => 'bold',
                             focused   => 'bold',
                             blurred   => '',
                             highlight => 'inverse',
                             cursor    => 'inverse',
                             active    => 'bold inverse',
                             disabled  => 'faint',
                             error     => 'bold inverse';

constant $default-attr4bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'italic',
                             link      => 'bold underline blue',
                             input     => '',
                             prompt    => 'bold',
                             focused   => 'on_blue',
                             blurred   => '',
                             highlight => 'bold white on_blue',
                             cursor    => 'inverse',
                             active    => 'bold inverse',
                             disabled  => 'faint',
                             error     => 'red';

constant $default-attr8bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'italic',
                             link      => 'bold underline ' ~ rgb-color-flat(.2, .2, 1),
                             input     => '',
                             prompt    => 'bold',
                             focused   => 'on_' ~ gray-color(.25),
                             blurred   => 'on_' ~ gray-color(.3),
                             highlight =>         rgb-color-flat(1, 1,  1)
                                       ~ ' on_' ~ rgb-color-flat(0, 0, .8),
                             cursor    => 'inverse',
                             active    => 'bold inverse',
                             disabled  => 'faint',
                             error     =>         rgb-color-flat(1, 0, 0);

constant $default-attr8tango = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'italic',
                             link      => 'bold underline 75',
                             input     => '',
                             prompt    => 'bold',
                             focused   => 'on_238',
                             blurred   => 'on_239',
                             highlight => '255 on_62',
                             cursor    => 'inverse',
                             active    => 'inverse',
                             disabled  => 'faint',
                             error     => '160';


### 'pure' variants: ColorSets with no attributes or mixed color depth requirements

# NOTE: 'bold' is a special case because it is overloaded to mean 'bright'
constant $default-pure4bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'cyan',
                             link      => 'bold blue',
                             input     => '',
                             prompt    => 'bold',
                             focused   => 'on_blue',
                             blurred   => '',
                             highlight => 'bold white on_blue',
                             cursor    => 'bold blue on_white',
                             active    => 'bold blue on_white',
                             disabled  => 'yellow',
                             error     => 'red';

constant $default-pure8bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      =>         rgb-color-flat( 0, .8, .8),
                             link      =>         rgb-color-flat(.2, .2,  1),
                             input     => '',
                             prompt    => '',
                             focused   => 'on_' ~ gray-color(.25),
                             blurred   => 'on_' ~ gray-color(.3),
                             highlight =>         rgb-color-flat(1, 1,  1)
                                       ~ ' on_' ~ rgb-color-flat(0, 0, .8),
                             cursor    =>         rgb-color-flat( 0,  0,  1)
                                       ~ ' on_' ~ rgb-color-flat(.8, .8, .8),
                             active    =>         rgb-color-flat( 0,  0,  1)
                                       ~ ' on_' ~ rgb-color-flat(.8, .8, .8),
                             disabled  =>         gray-color(.5),
                             error     =>         rgb-color-flat(1, 0, 0);

# Reference: Approximation of Tango terminal color scheme using 8-bit color palette
#
#   BASE      DIM   BRIGHT
#   Black     236   240
#   Red       160   196
#   Green      70   113
#   Yellow    178   227
#   Blue       62    75
#   Magenta    96   139
#   Cyan       30    80
#   White     252   255

# Pure 8-bit, but using Tango + xterm-256 palette mapping to pseudo-match Tango 4-bit
constant $default-pure8tango = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => '30',
                             link      => '75',
                             input     => '',
                             prompt    => '',
                             focused   => 'on_238',
                             blurred   => 'on_239',
                             highlight => '255 on_62',
                             cursor    => '75 on_252',
                             active    => '75 on_252',
                             disabled  => '244',
                             error     => '160';


### Default ColorTheme

constant $DEFAULT-THEME is export = Terminal::Widgets::ColorTheme.new:
                                    moniker  => 'default',
                                    name     => 'color-themes' ¢¿ 'Default',
                                    desc     => 'color-themes' ¢¿ 'Default color theme',
                                    variants => %(
                                        attrmono   => $default-attrmono,
                                        attr4bit   => $default-attr4bit,
                                        attr8bit   => $default-attr8bit,
                                        attr8tango => $default-attr8tango,
                                        pure4bit   => $default-pure4bit,
                                        pure8bit   => $default-pure8bit,
                                        pure8tango => $default-pure8tango,
                                    );
