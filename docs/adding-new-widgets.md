# Adding New Widget Types

Adding new widget types isn't difficult, but there are a few steps you'll need
to take so that your new widget type fits into the existing structure, plus a
few extra if you want to include your new widget type into the base
Terminal::Widgets repository (as opposed to shipping it yourself as a separate
repo/module distro).


## Pick a Class Name

If your new widget will be part of a group of similar widgets, such as the form
input widgets or viewer widgets, your new class should be in that namespace,
and not include the namespace in the shortname.  In other words, prefer
`Terminal::Widgets::Input::Button` over `Terminal::Widgets::ButtonInput`.

Choose a class name that seems to match the general pattern of existing widget
class names and is unlikely to be confusing to readers.


## Set Up Your Repo

Whether you intend to contribute to the module ecosystem or directly to T::W
itself, you'll need a repo set up properly.


### Ecosystem: Create a New Repo

Create a new repo skeleton with `mi6` (from App::Mi6):

```
$ mi6 new Terminal::Widgets::Your::Classname
$ cd Terminal-Widgets-Your-Classname
```

Add a dependency in `META6.json` on T::W:

```
  "depends": [
    "Terminal::Widgets:auth<zef:japhb>:ver<0.2.4+>"
  ],
```

Terminal::Widgets tries to remain compatible across revisions within a minor
version, so make sure you specify a dependency on the actively maintained
version series.

While you're here, make sure your `auth`, `authors`, `description`, and
`license` are all accurate too.


### Direct Contribution: Fork the `Terminal-Widgets` Repo

Fork the repo from https://github.com/japhb/Terminal-Widgets to your own GitHub
(or other Git hosting service) user account, clone that fork to your local
workspace, and create a feature branch so that you aren't working in `main`:

```
$ git clone git@github.com:your_user/Terminal-Widgets.git Terminal-Widgets-your_user
$ cd Terminal-Widgets-your_user
$ git checkout -b new-branch-name
```

A decent default branch name pattern is
`<github username>-add-<namespaced new widget name>`; for example,
`japhb-add-input-button`.


## Create the Widget Class

It's usually easiest to start by copying an existing similar widget's class
module and making the necessary changes from there.  (Don't start from the
`Widget.rakumod` base module; it's mostly common code that you shouldn't need
to worry about unless you're planning to override that common behavior.)

Don't forget to change any `use`, `does`, or `is` lines as appropriate.  You
must inherit from `Terminal::Widgets::Widget` but you can do so via one of its
subclasses or subroles, such as `Terminal::Widgets::TopLevel`,
`Terminal::Widgets::Input`, or `Terminal::Widgets::SpanBuffer`.

You'll need to `use` a few additional modules; you can drop any that don't
apply:

```raku
use Terminal::Widgets::TextContent;  # To work with spans and span trees
use Terminal::Widgets::Layout;       # To register a layout class
use Terminal::Widgets::Events;       # To respond to input events
use Terminal::Widgets::Focusable;    # To accept keyboard focus
```

To respond to input events, you'll need to provide `multi method handle-event()`
implementations at least for `KeyboardEvent` and `MouseEvent`; see existing
examples for ideas, or just leave them empty for now if you prefer to do TDD
(Test-Driven Development).

Don't forget to `git add` the new class module so that tools that key off the
Git index will notice it.  You don't need to actually `git commit` yet, this
is just making sure there's an index entry at all.


## Add a `use` Test

If you're working in a fork of the Terminal-Widgets repo, just add a line in
the proper order in `t/00-use.rakutest`; in particular, make sure that all its
dependencies are earlier in the test file, and any modules likely to make use
of it are later.  If it has default exports (most widget modules won't), make
sure to use `Empty` for the import list.

If you're working in a fresh repo, you can create a new test file with just the
following (if `mi6` didn't already create one for you):

```raku
use Test;

use Terminal::Widgets::Your::Classname;

pass 'all modules loaded successfully';
done-testing;
```

In either case, you can now run `mi6 test` to check for loading errors and to
make sure the new module is added to `META6.json`.


## Create a Custom Layout Node

Add a (probably trivial) layout subclass at the top of your file, after the
`use` statement block.  You should most likely base your layout subclass on
either Terminal::Widgets::Layout::Leaf (for widgets that cannot have children)
or Terminal::Widgets::Layout::Node (for widgets that can).  You'll also need to
name the convenience method created for the layout builder
(Terminal::Widgets::Layout::Builder, if you're curious) to use widget as part
of your UI.

Here's an example pulled directly from the implementation of the tree viewer
widget:

```raku
#| Layout node for a tree viewer widget
class Terminal::Widgets::Layout::TreeViewer
   is Terminal::Widgets::Layout::Leaf {
    method builder-name() { 'tree-viewer' }
}
```

There are a few other methods you can add (see similar widget implementation
modules for details), but the above is the bare minimum.


## Link the Widget and Layout Classes

Add a method to your widget implementation class that links the widget and
layout classes.  Here's another example from the tree viewer module:

```raku
class Terminal::Widgets::Viewer::Tree
 does Terminal::Widgets::SpanBuffer
 does Terminal::Widgets::Focusable {

    # ... Widget attribute declarations ...

    method layout-class() { Terminal::Widgets::Layout::TreeViewer }

    # ... Actual widget implementation ...
}
```

Note that there are NO QUOTES around the class name; this is a direct
reference to the class type itself.


## Self-Register Your Widget

At the bottom of your widget implementation file, add the following:

```raku
# Register Your::Classname as a buildable widget type
Terminal::Widgets::Your::Classname.register;
```

This will cause your widget to self-register into the proper places when the
module is loaded, so that it can be transparently used as normal.


## Extra for T::W Forks

If you're working in a Terminal-Widgets fork (rather than a new repo) then
add a `use` statement for your new widget module in the proper order in
`StandardWidgetBuilder.rakumod`.  This will ensure that the widget is loaded
and registered when using the Terminal::Widget::Simple API.

Re-run `mi6 test` at this point to make sure your additions so far don't have
any typos.


## Add Example(s)

Add example scripts to the repo's `examples/` directory, or modify existing
examples to use your new widget as appropriate.  For example, if you create a
new form input widget, you may want to add it to `examples/form.raku` to
demonstrate its usage.  This also gives you an opportunity to make sure its
behavior makes sense in context.


## Add Tests *(if you haven't already)*

If you *haven't* been developing the new widget using TDD, now's the time to
write tests for it, and iterate on fixing bugs until the tests are once again
clean.  Make sure to test error handling as well.


## Commit

With all tests passing and examples working, you can now commit your new widget
and all the associated changes.  Don't forget that you may need to add any new
changes to the class module since you first did `git add` above, otherwise you
will commit the original out-of-date version.

If you're contributing back to the core Terminal-Widgets repo, please use a
clear title and description for your commit, because it will show up in your
pull request.


## Contribute Your Widget

The final step depends on whether you are working in a fork or your own repo.


### Send a Pull Request

If you're working in a fork, preparing to contribute to the core repo, push
your commit to your fork using `git push -u origin <the-branch-name>`.  The
commit response from GitHub will include a URL that you can browse to create
the PR to include your new widget in `Terminal-Widgets`.  Once you've created
the PR, a message will be sent to the maintainer (currently `japhb`) to review.


### Push and Upload Your Module

If you've created your own module, follow your Git hosting provider's
instructions for creating the hosted repo and pushing your local repo to it.

Once that's in place, you can run `mi6 release` to release your module to the
zef/fez ecosystem.  Once the module has been indexed, please tell everyone
about it!  To check if it's been indexed, run:

```
$ zef update && zef search Terminal::Widgets::Your::Classname
```


## Bask in the Praise

Thank you!  We really appreciate your contribution!

Now come to `#mugs` on Libera.Chat so that we can thank you again.  :-)
