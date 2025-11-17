# Viewer Widgets

This directory contains widgets that are primarily viewers for data, but which
are NOT charts/visualizers (use the `Viz/` directory for that).

For example, log tailers, tree navigators, and doc viewers all belong here.


## Interactivity

Viewers can have basic viewing interactivity, such as scroll or expand/collapse
actions, but are not primarily intended as inputs.  Widgets that primarily
act as inputs should prefer the `Input/` directory instead.

For example, a rich text _viewer_ would belong here, but a rich text _editor_
would belong in `Input/`.


## Efficiency

Like the visualizers, viewers can often operate on large data sets.  Care
should be taken to work as efficiently/lazily as possible on large or complex
files, large directory trees, and so forth.
