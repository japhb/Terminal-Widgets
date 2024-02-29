# ABSTRACT: Premade ColorTheme palettes

use Terminal::Widgets::I18N::Translation;
use Terminal::Widgets::Utils::Color;
use Terminal::Widgets::ColorTheme;


### 'attr' variants: ColorSets with italic/inverse/underline attributes enabled

constant $default-attrmono = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'italic',
                             link      => 'underline',
                             input     => '',
                             focused   => 'bold',
                             blurred   => '',
                             highlight => 'inverse',
                             active    => '',
                             disabled  => '',
                             error     => 'inverse';

constant $default-attr4bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'italic',
                             link      => 'underline',
                             input     => '',
                             focused   => 'on_blue',
                             blurred   => '',
                             highlight => 'bold white on_blue',
                             active    => 'bold inverse',
                             disabled  => 'bold black',
                             error     => 'red';

constant $default-attr8bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'italic',
                             link      => 'underline ' ~ rgb-color-flat(.2, .2, 1),
                             input     => 'on_' ~ gray-color(.05),
                             focused   => 'on_' ~ gray-color(.15),
                             blurred   => 'on_' ~ gray-color(.3),
                             highlight =>         rgb-color-flat(1, 1,  1)
                                       ~ ' on_' ~ rgb-color-flat(0, 0, .8),
                             active    => 'inverse',
                             disabled  =>         gray-color(.5),
                             error     =>         rgb-color-flat(1, 0, 0);


### 'pure' variants: ColorSets with no attributes or mixed color depth requirements

constant $default-pure4bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      => 'cyan',
                             link      => 'bold blue',
                             input     => '',
                             focused   => 'on_blue',
                             blurred   => '',
                             highlight => 'bold white on_blue',
                             active    => 'bold blue on_white',
                             disabled  => 'bold black',
                             error     => 'red';

constant $default-pure8bit = Terminal::Widgets::ColorSet.new:
                             text      => '',
                             hint      =>         rgb-color-flat( 0, .8, .8),
                             link      =>         rgb-color-flat(.2, .2,  1),
                             input     => 'on_' ~ gray-color(.05),
                             focused   => 'on_' ~ gray-color(.15),
                             blurred   => 'on_' ~ gray-color(.3),
                             highlight =>         rgb-color-flat(1, 1,  1)
                                       ~ ' on_' ~ rgb-color-flat(0, 0, .8),
                             active    =>         rgb-color-flat( 0,  0,  1)
                                       ~ ' on_' ~ rgb-color-flat(.8, .8, .8),
                             disabled  =>         gray-color(.5),
                             error     =>         rgb-color-flat(1, 0, 0);

### Default ColorTheme

constant $DEFAULT-THEME is export = Terminal::Widgets::ColorTheme.new:
                                    moniker  => 'default',
                                    name     => 'color-themes' ¢¿ 'Default',
                                    desc     => 'color-themes' ¢¿ 'Default color theme',
                                    variants => %(
                                        attrmono => $default-attrmono,
                                        attr4bit => $default-attr4bit,
                                        attr8bit => $default-attr8bit,
                                        pure4bit => $default-pure4bit,
                                        pure8bit => $default-pure8bit,
                                    );
