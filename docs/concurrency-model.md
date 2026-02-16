# Terminal::Widgets Concurrency Model

## Background

Full-screen TUIs (Terminal User Interfaces) need to deal with a great deal of
asynchrony.  The terminal interface itself works a bit like a point-to-point
streaming network connection; output to, and input from, the user's terminal
can happen at any moment, and won't necessarily arrive in the same chunks a
programmer might naively expect.

Beyond the fundamental asynchrony of the terminal itself, it is quite common
for the app to receive other input triggers, including actual networking, IPC,
timer expiration, system signals, etc.  Furthermore individual widgets may wish
to communicate with each other as a result of some internal state change, and
the app's overall data model may send periodic updates to listening objects.

Concurrency is built into the Raku language design, and it is easy to push
work into multiple running threads and background tasks.  Without some cohesive
concurrency model, it would be very easy to accidentally introduce numerous
threading hazards just waiting to crash the app or corrupt its state.

Thankfully Raku also provides a strong suite of concurrency control tools, and
Terminal::Widgets (AKA 'T-W') and its dependencies build on these to provide
safety.


## The Terminal::* Stack

Terminal::Widgets is built on a stack of lower-level Raku modules.  Here's an
overview of the concurrency status of each:

    MODULE                 | CONCURRENCY  | PURPOSE
    -----------------------|--------------|--------
    Terminal::LineEditor   | Supplies     | Raw terminal input
    Terminal::Print        | Grid Locking | Screen grid output
    Terminal::API          | -managed-    | OS-level terminal mode controls
    Terminal::ANSIParser   | -managed-    | Parses ANSI/VT input codepoint stream
    Terminal::Capabilities | -none-       | Determines terminal/font capabilities
    Terminal::ANSIColor    | -none-       | Encodes/decodes ANSI SGR escapes
    Text::MiscUtils        | -none-       | Calculates duospace widths


### Concurrency `-none-`

The modules marked with concurrency `-none-` do NOT perform or require any
concurrency management for one of two main reasons:

  1. They provide only pure functions, thus aren't affected by concurrency
  2. Their state is immutable after object creation and are likewise unaffected


### Concurrency `-managed-`

These modules do have some concurrency risk, but have an API contract placing
the concurrency control burden on the calling code; they are thus managed by
the caller's controls.

Terminal::API is a classic example of this.  It provides access to OS-level
terminal mode APIs that could easily cause I/O corruption if called at the
wrong time, and it is the responsibility of the calling code (in this case,
Terminal::LineEditor) to make sure that these calls only occur when safe.

Terminal::ANSIParser also falls into this category; it works as a conversion
pipe containing an internal state machine.  Bytes or Unicode codepoints go in
one end and parsed escape sequence tokens come out the other.  Critically
however, the function for emitting new tokens is NOT defined internally by
T-AP, but rather is provided by the caller.  This allows T-AP users to slot it
directly into their own preferred concurrency model and is how T-LE uses T-AP
safely.


### Terminal::Print: Grid Locking

Terminal::Print is used to provide the screen grid abstraction that T-W depends
on, and in fact a T-W `Widget` is also a T-P `Widget`.  However, T-W doesn't
use all of T-P's functionality, and this simplifies the concurrency situation.

While T-P *can* parse raw terminal input, it uses an older, incomplete, and
less error-resilient algorithm, so T-W prefers the more advanced T-LE/T-AP pair
for input parsing instead.  Similarly, while T-P offers some concurrency-aware
timing utilities, T-W doesn't use them and uses its own perf timing method
instead.

That leaves three remaining fundamental T-P concurrency issues to address:

  1. Overlapping writes to the terminal corrupting *output*
  2. Overlapping writes to the grid data corrupting *state*
  3. Overlapping reads and writes to the grid making partial changes visible

As a first step, the individual cells within a grid are represented using
immutable objects: either plain Raku strings (when **no** SGR attributes apply
to the cell) or `Cell` objects (when the cell **has** SGR attributes).  The
only "update" operation on a cell is replacement of it.  This also means that
`Cell` objects can be cached and reused, which can be important for performance
in some cases.

Next, T-P separates the concepts of grid *modification* (replacing cells in the
grid array) and grid *compositing* (copying grid contents to another widget or
to the actual terminal output).

To take advantage of this semantic separation, all methods on a T-P grid are
made to implicitly hold a per-grid lock by making the `Grid` class a *monitor*
using the OO::Monitors module.  Any call to a `Grid` method grabs the lock, and
this is held transparently through recursive or mutual calls, so that only
returning from the first called method releases the lock.

To prevent printing a partially modified grid, stringification into the form
needed for terminal output happens through locked `Grid` method calls:
`cell-string`, `span-string`, or `Str`.  They thus cannot happen at the same
time as a mutation method on the same grid.

Likewise to prevent overlapping writes, the grid lock must be held on the
**destination** grid for any mutating operation.  Because it is a monitor, the
easiest way to do this is to call a method on that destination grid to perform
the mutation.  For example, a composite operation from one grid into another
would call `$dest-grid.copy-from($source-grid)`.

While `Grid` provides a number of basic mutation methods, there will still be
times that callers need to make complex changes that would be prohibitively
slow using many separate mutation method calls, partially because of the
overhead of grabbing and releasing the grid lock over and over.  For this case
there is a special `Grid.with-grid-lock` method, which simply grabs the lock
once before calling an arbitrary caller-provided routine, releasing the lock
after the routine completes.  T-W uses `with-grid-lock` in a few critical-path
cases.


### Terminal::LineEditor: Supplies

Terminal::LineEditor::RawTerminalIO runs two key background tasks:

  1. The *parser*, which feeds raw input through T-AP to a parsed token Supplier
  2. The *decoder*, which takes parser tokens and feeds a decoded input Supplier

Since the decoder only listens to the parsed token Supply, it runs continuously
via `react` once started, only exiting when terminal I/O is finally shut down
at program end.  Terminal::Widgets::Terminal listens to the output Supply from
T-LE's decoder reactor (among other things).

On the other hand since the program might be suspended -- during which time it
should NOT be grabbing input data -- the reader/parser task only runs when the
app has full control of the terminal.  Existing Suppliers/Supplies stay active
but receive no data while the parser is not running.

T-LE is also responsible for managing the concurrency of two other modules in
the stack, Terminal::ANSIParser and Terminal::API, via the `enter-raw-mode`,
`leave-raw-mode`, `start-parser`, and `set-done` methods.


## Terminal::Widgets Itself

Several pieces of T-W require concurrency control.  Some modules pass the
concurrency control burden to their callers.  Others automatically manage
external sources of concurrency, or even introduce their own concurrency.


### Caller-Managed Modules

These modules could be sensitive to concurrency hazards, but require their
callers or derived classes to explicitly manage the concurrency for them.


#### App

The base App class is a singleton, and its *semantic* state could in theory be
corrupted by poorly-managed simultaneous access; the programmer must take care
not to do this when using the App class directly.

However, App's internal *data structures* -- collections of current Terminal
and TopLevel objects -- are lock-protected so they at least stay internally
consistent.

Moreover, programmers will almost never use or derive from the base App class
directly, instead using the Simple::App subclass, which both generates and
manages concurrency as needed.


### Concurrency-Safe Roles

These roles do not introduce any new concurrency of their own, but have state
that could easily be corrupted by concurrent calls.  Certain corruption modes
may not actually be reachable in the *current* T-W codebase, but it is likely
that new features and optimizations will over time expose more of these
hazards.

Thus each of these roles ensure safety by providing their own protection
mechanisms internally.  This not only aids future-proofing but maintains the
ability to easily reason about their behavior.


#### WidgetRegistry: Internal Locking

The widget registry is a global singleton which may be accessed from nearly
anywhere and during many phases of operation, including at module load time.

WidgetRegistry thus protects its data by making the global state module-private
and always accessing it while holding a singleton mutex lock.  This locking
is internal to the role and callers do not need to deal with it.


#### DirtyAreas: Internal Locking

The DirtyAreas protocol is a conversation between a parent widget and its
children, and calls to manage dirty areas for a given widget can happen
concurrently.  For instance, Terminal::Print supports fanning out redraws to
child widgets in parallel, though T-W doesn't use this optimization yet.

To keep this easy to reason about and avoid possible state corruption,
DirtyAreas does internal mutex locking as with WidgetRegistry.


#### Progress::Tracker: Supplies

The Progress::Tracker role explicitly supports async updates from multiple
concurrent callers, as it is expected that users will commonly want to track
the progress of backgrounded or parallelized workloads.

To manage this concurrency, Progress::Tracker funnels updates through an
internal Supplier/Supply pair which serialize the actual update operations.


### Concurrency Sources

These modules introduce additional concurrency sources; some is handled
internally or by API contract, and other pieces require care from the
programmer.


#### Simple::App

Simple::App operates almost exclusively during the app's startup phase, giving
up control to a newly-initialized Terminal object when it finishes.  It follows
a few simple concurrency control rules:

  1. Startup execution begins and ends on the same (usually main) thread
  2. Any short-lived spawned tasks will be independent and `await`ed before
     startup completes
  3. Any long-lived tasks (beyond startup) will be `start`ed in the background
     and not affect startup otherwise

Simple::App's methods call numerous hooks that subclasses can override for
custom or more advanced behavior.  The subclass programmer is then responsible
for following the above rules directly, or adding their own concurrency
controls that prevent violation of those rules.

Startup begins with the `bootup` method, which internally calls the `boot-init`
subclass hook.  Even if the subclass's `boot-init` creates background tasks, it
should still return back to `bootup` in the same thread it was called from, in
accordance with rule 1.

Next, a controlling Terminal object representing the user's terminal emulator
is added, usually with autodetected capabilities.  If the app wants to boot
directly into a normal UI screen, a TopLevel object is created for this as
well.

`$terminal.initialize` is then called, which initializes the terminal's
*alternate screen* where the TUI will be drawn, and starts the T-LE input token
decoder as a background reactor task.  This follows rule 3 and has no other
effect on startup.

If the app wants a transitional loading screen, it creates a concurrency-safe
Progress::Tracker and hands it off to the `loading-promises` subclass hook,
which as the name implies returns a list of completion Promises to await for
the short-lived loading-time tasks.  Each time a task completes, it is expected
to update the Progress::Tracker; the loading screen itself sets the progress
complete when all the loading promises have been `await`ed.  In compliance with
rule 2, none of the tasks should affect each other or modify shared state
without (additional) explicit concurrency control.

Finally, Simple::App either returns the Terminal object to the calling program
for final tweaks, or in the case of `boot-to-screen` just directly hands control
to the Terminal's reactor by calling `$terminal.start`.


#### Terminal

The Terminal object orchestrates overall execution throughout most of the app's
lifetime, mostly through the three reactor tasks it spawns:

  1. T-LE input token decoder: Started in the background by `initialize`
  2. T-LE input stream parser: Started in the background by `enter-raw-mode`
  3. Primary terminal reactor: Run on the main thread in `start`

As mentioned [earlier](#terminal-lineeditor-supplies), T-LE manages all its own
concurrency hazards, with final output being a concurrency-safe Supply of
decoded tokens.

The primary terminal reactor listens to the following:

  1. `control` Channel:      Safely handles ops that require exclusive control
  2. `async-events` Channel: Forwards high-level Events to the current toplevel
  3. `sync-events` Supply:   Same as #2, except synchronous
  4. T-LE `decoded` Supply:  Same as #3, after wrapping into high-level Events
  5. OS signals (SIGWINCH):  Converted to control channel messages so signal
                             handler can return immediately

As with all Raku `react` blocks, there is automatic mutual exclusion between
the `whenever` listeners -- none can be entered while one is already active.
This is the most important serializer in a T-W app and of course a boon for
reasoning about overall behavior, but could be a source of poor responsiveness
if items queue for too long before dispatch.


## Event Model

When the Terminal reactor receives or generates a high-level Event, it calls
`$.current-toplevel.process-event($event)` to hand it off to the currently
visible TopLevel UI for processing.  Note that as a normal method call within a
`whenever` block, this processing happens in the reactor's current thread and
thus BLOCKS TERMINAL PROCESSING until it completes (or explicitly pushes
further work to the background).

Events are usually generated automatically by wrapping keyboard or mouse inputs
coming from the T-LE input token decoder.  The programmer can also directly
inject Events to be processed by calling `$terminal.send-event($event)`,
optionally adding the `:async` flag to have them sent through an async Channel
rather than synchronously as is the default.  Whichever option is chosen, the
event processing will still be mutually excluded from other Events by the main
terminal `react` block.

XXXX: HERE
