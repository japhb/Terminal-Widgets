# Adding New Widgets

Adding new widgets isn't difficult, but it does involve making changes in
several places.  This doc records the steps you'll need to take.


## Fork the `Terminal-Widgets` Repo

Fork the repo to your own GitHub user account, and clone the fork to your local
workspace.


## Pick a Class Name

If your new widget will be part of a group of similar widgets, such as the form
input widgets, your new class should be in that namespace, and not include the
namespace in the shortname.  In other words, prefer
`Terminal::Widgets::Input::Button` over `Terminal::Widgets::ButtonInput`.

Choose a class name that seems to match the general pattern of existing widget
class names and is unlikely to be confusing to readers.


## Create a Feature Branch

Use `git checkout -b <new-branch-name>` to make sure you're not working in
`main`.  A decent default branch name pattern is
`<github username>-add-<namespaced new widget name>`; for example,
`japhb-add-input-button`.


## Create the Widget Class

It's usually easiest to start by copying an existing similar widget's class
module and making the necessary changes from there.  Don't forget to change
any `use`, `does`, or `is` lines as appropriate.  You must inherit from
`Terminal::Widgets::Widget` but you can do so via one of its subclasses or
subroles, such as `Terminal::Widgets::TopLevel` or `Terminal::Widgets::Input`.

You'll need to provide `multi method handle-event()` implementations at least
for `KeyboardEvent` and `MouseEvent`; see existing examples for ideas, or just
leave them empty for now if you prefer to do TDD (Test-Driven Development).

Don't forget to `git add` the new class module so that tools that key off the
Git index will notice it.  You don't need to actually `git commit` yet, this
is just making sure there's an index entry at all.


## Add the New Module to `t/00-use.rakutest`

Add a line to `use` the new module in the appropriate order in
`t/00-use.rakutest`; in particular, make sure that all its dependencies are
earlier in the test file, and any modules likely to make use of it are later.
If it has default exports (most widget modules won't), make sure to use `Empty`
for the import list.

Run `mi6 test` to check for loading errors and to make sure the new module is
added to `META6.json`.


## Update a Layout Node

Add a (probably trivial) subclass to `lib/Terminal/Widgets/Layout.rakumod` that
will perform layout for the new widget, assigning it an appropriate superclass,
such as `Leaf` (for widgets that cannot have children) or `Node` (for widgets
that can).

Also add a convenience method to the `Builder` class in that same file to make
it easy to add that layout node to a widget layout tree.


## Add a StandardWidgetBuilder Case

Add a case in the `Terminal::Widgets::StandardWidgetBuilder` class that will
handle building your new widget type given the computed layout information.
Don't forget that you will need to add your new widget class to the list of
`use` statements at the top of the file.

Re-run `mi6 test` at this point to make sure your additions to `Layout` and
`StandardWidgetBuilder` compile.


## Add Example(s)

Add example scripts to the `examples/` directory, or modify existing ones to
use your new widget as appropriate.  For example, if you create a new form
input widget, you may want to add it to `examples/form.raku` to demonstrate
its usage.  This also gives you an opportunity to make sure its behavior makes
sense in context.


## Add Tests *(if you haven't already)*

If you *haven't* been developing the new widget using TDD, now's the time to
write tests for it, and iterate on fixing bugs until the tests are once again
clean.  Make sure to test error handling as well.


## Commit

With all tests passing and examples working, you can now commit your new widget
and all the associated changes.  Don't forget that you may need to add any new
changes to the class module since you first did `git add` above, otherwise you
will commit the original out-of-date version.

Please use a clear title and description for your commit, because it will show
up in your pull request.


## Send a Pull Request

Push your commit to your fork using `git push -u origin <the-branch-name>`; the
commit response from GitHub will include a URL that you can browse to create
the PR to include your new widget in `Terminal-Widgets`.  Once you've created
the PR, a message will be sent to the maintainer (currently `japhb`) to review.

Thank you!  :-)
