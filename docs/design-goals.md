# Design Goals and Philosophy

## Ease of Use

T-W widgets, and the applications written with them, should more or less act as
most users would expect.  Key bindings should be consistent and make sense to
most modern desktop users, edge case behaviors shouldn't be surprising, look
and feel should match general expectations, and so forth.

The application developer is of course free to mangle expectations to their
heart's content, but this should take *intentional effort* -- base behaviors
and defaults should just DWIM for a wide audience.


## Developer Experience

The overall Terminal::Widgets design aims to allow Raku programmers to write
concise, clear UI code for a wide variety of applications, *once they have
passed the initial learning curve.*  In other words, in balancing "ease of
first use" and "effectiveness for regular users", I decided on a middle
course: accepting *some* extra up-front effort in order to increase overall
day-to-day usefulness and power.

Of course this doesn't mean that T-W is strictly for experts or power users;
far from it in fact.  But I wanted to follow the general Raku philosophy that
the easy things should be easy, the hard things should be achievable, and
minimalism takes a back seat where it conflicts with either of the other goals.

(For help getting up to speed, see the [Getting Started](getting-started.md)
doc; after working through it, you should be able to read and understand any of
the scripts in the [`examples/`](../examples/) directory, and from there modify
them or build various simple UIs of your own.)


## Compatibility

Even though essentially all terminal emulators in general use today (such as
`xterm`, Ghostty, or Windows Terminal) are intended to emulate the same DEC VT
series of physical terminals as a bare minimum standard, the various emulator
programs and terminal fonts still offer vastly different feature sets and
Unicode compliance levels.

Smoothly making the best use of available features in every case would be a
heavy burden for the application programmer, in most cases resulting in only
supporting the least common denominator or the features available in just the
terminals and fonts that the programmer personally has available.

To avoid this, Terminal::Widgets makes it easy for widgets to support various
feature levels transparently.  All standard widgets make use of this, and will
automatically adjust their look and behavior to match the user's terminal and
preferences, based on autodetection from Terminal::Capabilities and lessons
learned from Terminal::Tests.

Of course the existing premade widgets may not include everything needed for
your UI, and for this reason Terminal::Widgets provides support for building
custom widgets of your own -- and even releasing them in the Raku ecosystem
separately knowing that they will automatically register themselves for use by
Terminal::Widgets applications.
