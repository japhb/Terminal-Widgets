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

XXXX: HERE
