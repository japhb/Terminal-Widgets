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

T-W event handling is similar to web browser event handling.  Events such as
`KeyboardEvent`, `MouseEvent`, `TakeFocus`, or `LayoutBuilt` are injected into
the currently visible `TopLevel`, which trickles each event down to its
children recursively until reaching the event's target (if there is one) or the
leaves of the widget tree, where it begins a journey of bubbling back up to the
TopLevel.

Thus there are three phases to an event's journey that widgets can act on:

  * `TrickleDown`
  * `AtTarget`
  * `BubbleUp`

This allows any widget to choose to handle an event either before or after its
children, or only when it is the event target, simply by choosing which phase
to listen to.

In order to better control which widgets should receive a particular event,
there are several event classes:

  * `GlobalEvent`         - Sent to every widget
  * `TargetedEvent`       - Sent to one particular widget, ignored by others
  * `LocalizedEvent`      - Sent to widgets overlapping a particular X,Y location
  * `FocusFollowingEvent` - Sent to only the focused widget and its parents

Here's how the standard event types fit into those categories:

  * `GlobalEvent`         - `LayoutBuilt`
  * `TargetedEvent`       - `TakeFocus`
  * `LocalizedEvent`      - `MouseEvent`
  * `FocusFollowingEvent` - `KeyboardEvent`

The base `Widget` class does the `EventHandling` role, which allows a widget
to handle some subset of events by adding a `multi method handle-event` with
sufficiently precise arguments.  Here's an example of a mouse event handler
shared among several of the `Input` widget types:

```raku
    #| Handle basic mouse click event
    multi method handle-event(Terminal::Widgets::Events::MouseEvent:D
                              $event where !*.mouse.pressed, AtTarget) {
        # Always focus on mouse click, but only perform click action if enabled
        self.toplevel.focus-on(self);
        self.click if $.enabled;
    }
```

Note how the multi method parameters specify only `MouseEvent`s where the
mouse button is being released (the end of a click), and only when the event
has reached its target (phase `AtTarget`).


## Widget Layout and the Box Model

Widgets are laid out in a hierarchy of X-Y grids, each laying flat within a
stack of Z-planes.  Even without any Z-offset, child widgets are assumed to be
infinitesimally closer to the viewer than their parent so that the painting
and compositing orders are well-defined:

```
┌PARENT─────────────────────────────┐
│ ┌CHILD─────────┐ ┌CHILD─────────┐ │
│ │ ┌GRANDCHILD┐ │ │ ┌GRANDCHILD┐ │ │
│ │ └──────────┘ │ │ └──────────┘ │ │
│ │ ┌GRANDCHILD┐ │ │ ┌GRANDCHILD┐ │ │
│ │ └──────────┘ │ │ └──────────┘ │ │
│ └──────────────┘ └──────────────┘ │
└───────────────────────────────────┘
```

Within each widget, T-W uses a similar layout to the CSS box model.  The active
*content-area* sits in the middle and is surrounded by three types of *framing*
-- from innermost to outermost, the *padding*, *border*, and *margin*:

```
┌WIDGET────────────────────────────┐
│              margin              │
│                                  │
│    ╔═════════border═════════╗    │
│ m  ║                        ║  m │
│ a  ║         padding        ║  a │
│ r  ║  p ┌──────────────┐ p  ║  r │
│ g  ║  a │ Content Area │ a  ║  g │
│ i  ║  d └──────────────┘ d  ║  i │
│ n  ║         padding        ║  n │
│    ║                        ║    │
│    ╚═════════border═════════╝    │
│                                  │
│              margin              │
└──────────────────────────────────┘
```

The upper left corner within a widget grid is at x=0,y=0,z=0, but may be offset
by arbitrary integer offsets from its parent (and through the chain of parents,
the entire TopLevel screen).  Positive values are to the RIGHT, DOWN, and
CLOSER to the viewer.

Here's the widget box model again, with coordinates added:

```
    │
    │ +y
    ▼
───▶┌WIDGET────────────────────────────┐╶╮
 +x │(0,0)         margin              │ │
    │                                  │ │
    │    ╔═════════border═════════╗    │ │
    │ m  ║                        ║  m │ │
    │ a  ║         padding        ║  a │ │
    │ r  ║  p ┌──────────────┐ p  ║  r │ │
    │ g  ║  a │ Content Area │ a  ║  g │ ├ h (height)
    │ i  ║  d └──────────────┘ d  ║  i │ │
    │ n  ║         padding        ║  n │ │
    │    ║                        ║    │ │
    │    ╚═════════border═════════╝    │ │
    │                                  │ │
    │              margin     (w-1,h-1)│ │
    └──────────────────────────────────┘╶╯
    ╰────────────────┬─────────────────╯
                     w (width)
```


## Drawing Sequence


## Widget Builtin Roles

In order to provide many common behaviors and utility methods, the base
`Widget` class is fairly extensive and does numerous roles.  Most of these
you won't have to think about when building your own apps and custom widget
classes, except maybe to use provided helpers and standard boilerplate; they
mostly Just Work.

Here's the list for the curious:

  * `Terminal::Print::Widget`       - Use T-P's low-level cells, grid, and compositor
  * `Terminal::Print::Animated`     - Allow timestamp-aware full-hierarchy redraws
  * `Terminal::Print::BoxDrawing`   - Draw borders using various line styles
  * `Terminal::Widgets::Common`     - Provide common debugging and profiling helpers
  * `Terminal::Widgets::Themable`   - Control color and attributes via semantic states
  * `Terminal::Widgets::DirtyAreas` - Support dirty-area compositing optimization
  * `Terminal::Widgets::WidgetRegistry`        - Register new widget types on load
  * `Terminal::Widgets::Events::EventHandling` - See previous section

Note that the first three of those are from `Terminal::Print`, which T-W is
based on and interoperable with.


## Debugging and Profiling

Because of the highly-interconnected nature of T-W objects, it can be confusing
to log, debug, trace, or profile a T-W app's execution; `dd` or `.raku` on any
widget are likely to end up dumping many pages of output.  To make this easier,
the `Common` role and `Widget` class together provide a number of helper methods:

  * `gist`             - Avoids recursive dumping and summarizes key attributes
  * `gist-name`        - Class name shortened for readability
  * `gist-flags`       - Used by `gist` to report special flags on the widget
  * `gist-dirty-areas` - Used by `gist` to summarize the widget's dirty areas

  * `debug`         - Cache of `$*DEBUG` verbosity at time of object creation
  * `debug-grid`    - Return an optionally framed snapshot of a single widget
  * `debug-elapsed` - Write a debug note for elapsed time during an operation

  * `toplevel`      - Chase parent links to find widget's TopLevel
  * `terminal`      - Find this widget's controlling Terminal (via `toplevel`)
  * `default-focus` - Find descendent widget that should get focus by default

  * `first-widget`  - FIRST matching widget in subtree, starting at `self`
  * `last-widget`   - LAST matching widget in subtree, ending with `self`
  * `next-widget`   - Next matching widget AFTER `self` in full tree
  * `prev-widget`   - Previous matching widget BEFORE `self` in full tree

## TopLevel Widgets

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

---

For example, `Widget` does the `WidgetRegistry` role and provides a `register`
helper method, which introspects various subclass declarations to set up a
proper call to `self.register-widget` with all the right arguments.  But you
don't have to care about how any of that works.  You just have to know that
when you're creating a new widget type, if you follow the boilerplate in the
[Adding New Widget Types](adding-new-widgets.md) doc, and put a simple
`register` call at the end of your implementation file like this:

```raku
Terminal::Widgets::Your::Classname.register;
```

... your new widget type can then be used just like any builtin type would be.
