# Simple API Modules

Modules here are primarily intended to provide simpler interfaces to existing
functionality, often by providing helper functions or opinionated wrappers that
make the most commonly expected choices.

For example, the simplified TopLevel and App classes that allow the `examples/`
scripts to mostly ignore those details are here.

If your module/class would be generally useful to any program wanting a simple
API, you should also import/export it in the `Terminal::Widgets::Simple` module
so that callers don't need to import all of the `Simple` modules individually.
