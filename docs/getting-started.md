# Getting Started with Terminal::Widgets

## Overview

As the name implies, Terminal::Widgets (AKA "T-W") is a collection of modules
for creating Terminal User Interfaces (TUIs) using various visual *widgets*.
Widgets are rectangular tools that can be placed arbitrarily within the
terminal window, each doing a single thing.  Simple widgets include text
labels, buttons, checkboxes, menus, and specialty add-ons such as scrollbars.
More complex widgets include editor inputs, tree navigators, rich text viewers,
smoke charts, and more.

The smaller widgets used to design a particular TUI are laid out within a
special large widget called a *toplevel* that covers the entire terminal
window/viewport.  An *application* can be made up of many toplevels, each of
which lays out a single "screen" within the app, such as the main menu,
settings menu, online help docs, and so on.

While a toplevel manages screen layout, another critical object represents the
terminal itself -- terminal emulator capabilities, input decoding, active user
themes and preferences, the user's current locale and translation context, and
the reactive event dispatcher for that terminal session.

Here's a diagram of a trivial T-W UI in use:

```
USER         WINDOW        OBJECTS
                           App
👤💻─────╒════Hello════╕ ⟵ ├─Terminal
    ╲    │             │   │    ┆
     ╲   │             │ ⟵ └─TopLevel (HelloUI)
      ╲  │Hello, World!│     ├─PlainText
       ╲ │⌈Quit⌋       │     └─Button
        ╲│             │
         └─────────────┘
```


## Hello, World!

With that short overview in mind, let's start off by creating the classic
"Hello, World!" app from the diagram above.  Here's what that looks like in
Raku code:

```raku
use Terminal::Widgets::Simple;

#| A top level UI container based on Terminal::Widgets::Simple::TopLevel
class HelloUI is TopLevel {

    #| Define the initial UI layout when the TopLevel first starts up
    method initial-layout($builder, $width, $height) {

        # Use the layout builder to add a PlainText widget and a quit button,
        # centered in the terminal window and taking minimal space.
        with $builder {
            .center(:vertical, style => %(:minimize-h, :minimize-w),
                     .plain-text(text => 'Hello, World!', color => 'bold'),
                     .button(label => 'Quit',
                             process-input => { $.terminal.quit }),
                    )
        }
    }
}

sub MAIN() {
    # Boot a Terminal::Widgets::Simple::App and jump right to the main screen
    App.new.boot-to-screen('hello-world', HelloUI, title => 'Hello');
}
```

Using Terminal::Widgets::Simple defines and imports classes that handle all of
the basic TUI behaviors, including `App` (representing the application
lifecycle) and `TopLevel` (representing a full-window UI).  The `App` startup
process will eventually call our `initial-layout` method (more on this in the
next section) to define the widget layout constraints, and that's where most of
the code in this example resides.

A `Layout::Builder` object is provided as the first argument, and we use that
to request a centered, vertically stacked, minimum-size UI layout, containing a
simple `plain-text` message and a 'Quit' `button` that when clicked will tell
the terminal event reactor to quit (thus exiting the program as a whole).

For your convenience the above program has been saved in the
[hello-world example](../examples/hello-world.raku); go ahead and run this to
see what the result looks like.  You can mouse-click the Quit button or even
just press Enter to quit, since the first active input is automatically
focused for you.


## Startup Behind the Scenes

*This section details the startup process and explains why `MAIN` looks the way
it does; feel free to skip to the next section if this doesn't interest you
yet.*

The trivial `MAIN` used above creates a default `App` object and immediately
calls its `boot-to-screen` helper method to start up the application.  The
arguments are:

  1. An internal moniker for the initial screen (used by multi-screen apps)
  2. The `TopLevel` UI subclass that the helper method should instantiate first
  3. A title for the terminal window to use while showing the initial screen

As the name implies, `boot-to-screen` starts a UI bootstrapping sequence,
eventually ending with a fully rendered and interactive initial screen.

After some initial housekeeping, the user's terminal is autodetected and a
`Terminal` object created to manage it.  Next the specified `TopLevel` subclass
(in this case `HelloUI`) is instantiated with a reference to its controlling
`Terminal` object.  The boot sequence continues by calling
`Terminal.initialize` to blank the terminal window and start its input decoder,
and then calling `Terminal.set-toplevel` to prepare the `HelloUI` screen for
display.

`set-toplevel` begins by setting the terminal window title and then setting the
UI's height and width to the current window size, measured in character cells.
Finally it asks `HelloUI` to perform a `relayout` on itself.

A `relayout` begins by computing the actual layout details based on the
constraints specified by `HelloUI.initial-layout`.  It then builds the
requested child widgets and places them in the layout's computed rectangular
layout slots, and sends a `LayoutBuilt` event to all widgets to let them know
their siblings all exist and have been placed.  `relayout` finishes by setting
the input focus, then requesting a redraw and recomposite of all placed
widgets.

Finally, with the bootup process complete, the `App` object hands off control
to the user by starting `Terminal`'s primary input/event reactor.


## Event Handling

**XXXX: HERE**


## Basic Widget Structure

## TopLevel Widgets

## Layout and the Box Model

## The Application Object

## The Terminal Object

## Terminal Capabilities


## Further Reading

Now that you've gotten through this document, you're ready to take a more
detailed look at various parts of Terminal::Widgets.  Here are a few
suggestions:

* [Design Goals and Philosophy](design-goals.md) - The overall design goals
  that led to T-W's current design and implementation

* [Configuration and User Preferences](preferences.md) - Environment variables
  and terminal instance attributes used to configure the user's T-W experience

* [The Text Content Model](content-model.md) - Deeper details about the
  RenderSpan content model and the associated string conversion pipeline

* [Adding New Widget Types](adding-new-widgets.md) - A guide to creating your
  own custom widgets to supplement the premade widget collection


----

## XXXX: UNUSED PIECES

As simple as it is, our `initial-layout` method doesn't use its other two
arguments, which provide the width and height of the terminal window (measured
in character cells) in case the programmer wants to provide entirely different
layouts for small or large terminal windows.  This isn't needed when simply
*resizing* the same basic layout -- the builder's layout constraint solver does
that automatically -- but could for example instead be used to switch between
overview and detailed screen layouts based on available terminal real estate.
