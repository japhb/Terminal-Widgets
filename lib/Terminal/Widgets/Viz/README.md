# Data Visualizer Widgets

This directory contains widgets that are primarily data visualizers, such as
charting widgets.


## Interactivity

Some of these visualizers will be non-interactive, but it is perfectly
reasonable to have basic viewing interactivity, such as pan and zoom actions.
They are _not_ intended to be used as inputs, so if your widget allows you to
_edit_ the data being visualized, it probably belongs in `Input/` instead.


## Efficiency

Widgets here should be designed so that they are not constantly updating their
full area if possible.  For example, the SmokeChart widget keeps track of a
"sweep line" where updates occur, moving the sweep line as needed and leaving
other columns/rows unchanged.  This is vastly more efficient than the common
live charting style that updates in a fixed location (at one edge usually) and
moves the entire chart each time new data arrives.  As a pleasant side effect,
this also makes an actively updating SmokeChart much more "visually quiet",
and thus less distracting for the user.
