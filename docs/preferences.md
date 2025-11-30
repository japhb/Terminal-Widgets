# Configuration and User Preferences

Terminal::Widgets has two main ways to set config and user prefs:

* Environment variables
* Terminal instance attributes


## Environment Variables

All Terminal::Widgets-specific environment variables use a `TW_` prefix; the
remaining environment variables are general standards that Terminal::Widgets
respects.


### `LANGUAGE` or `LANG`

Used by `Terminal::Widgets::I18N::Translation::LanguageSelection` to detect
user's preference for translation languages.  If both are set, `LANGUAGE` is
preferred over `LANG`.


### `TERM`, `TERM_PROGRAM`, `COLORTERM`, and others

Used to detect the user's terminal emulator -- and terminal multiplexer if any
-- which helps to determine available terminal capabilities.  See
Terminal::Capabilities::Autodetect for recognized terminals and capabilities.


### `TW_DEBUG=<debug verbosity level>`

If >0, turn on Terminal::Widgets debugging (sent to the standard error stream).
Level 1 will enable the most basic debugging and timing info; higher levels
will enable successively more debug output.  Notably level 2 will turn on
debug views of every composited widget grid, and level 3 will turn on Backtrace
info.


### `TW_SYMBOLS=<symbol set name>`

Override an autodetected terminal symbol set with a different Unicode subset,
usually because the installed fonts don't support the full autodetected set.
See the Terminal::Capabilities documentation for available symbol set names.


### `TW_VT100_BOXES=<0|1>`

Override autodetection of VT100 box drawing capabilities.  This capability is
very minimal, so is almost universally supported by modern terminal emulators.
You may still turn this off and set `TW_SYMBOLS=ASCII` in order to test for
the most absolutely basic terminal support.


## Terminal Instance Attributes

When creating a new Terminal::Widgets::Terminal object (either directly with
`Terminal::Widgets::Terminal.new` or via `Terminal::Widgets::App.add-terminal`),
you can specify several configuration attributes:


### `caps`

A Terminal::Capabilities object describing available functionality in the
user's terminal emulator and fonts, such as support for 24-bit color or emoji
skin tones.  `App.add-terminal` will attempt to autodetect `caps` if adding the
processes's controlling terminal (`/dev/tty` on *nix systems).

If desired some of the capabilities can be overridden by environment variables
such as `TW_SYMBOLS` and `TW_VT100_BOXES`.


### `locale`

A Terminal::Widgets::I18N::Locale object describing the user's current locale
(translation string table, regional formatting rules, etc.).


### `ui-prefs`

A Hash of miscellaneous UI preference settings.  The following settings are
currently recognized by Terminal::Widgets:

* `Bool input-activation-flash` - If `True`, flash Input widgets when
  activated, such as when a Button is clicked.  Defaults to `False`.

* `UInt mouse-wheel-horizontal-speed` - Sets number of scrolled cells per mouse
  wheel horizontal event, defaulting to twice `mouse-wheel-vertical-speed`.

* `UInt mouse-wheel-vertical-speed` - Sets number of scrolled lines per mouse
  wheel vertical event, defaulting to 4 lines per event.

* `Bool scroll-invert-horizontal` - If `True`, invert the direction of
  horizontal scroll events.  Defaults to `False`.

* `Bool scroll-invert-vertical` - If `True`, invert the direction of vertical
  scroll events.  Defaults to `False`.
