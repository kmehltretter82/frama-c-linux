Contributing to Frama-C
=======================

There are several ways to contribute to Frama-C:

- Reporting bugs (via [Github](https://github.com/Frama-C/Frama-C-snapshot))
  or the [Mantis BTS](https://bts.frama-c.com);

- [Developing your own plug-in](http://frama-c.com/download/frama-c-plugin-development-guide.pdf)
  and sharing it with us;

- Asking questions and discussing in
  [StackOverflow](https://stackoverflow.com/tags/frama-c) and in
  the [Frama-C-discuss mailing list](https://lists.gforge.inria.fr/mailman/listinfo/frama-c-discuss);

- Submitting fixes and improvements via Github pull requests;

- Joining the [team](http://frama-c.com/about.html) (via internships, postdocs, open positions).


Contributed patches
===================

Main Frama-C development happens outside Github. By default, patches are
applied upstream and only release candidate and stable releases are pushed
to Github.

Therefore, non-trivial pull requests would be better served by creating a
branch and notifying Frama-C developers. If the patches are accepted, the
branch will be available on Github until the next Frama-C release incorporates
it.

Note that, in the case of bug fixes, it would be ideal to add test cases
to the appropriate subdirectory in `tests`. The plug-in developer manual
includes a section on the `ptests` tool used by Frama-C developers
(or you can provide the test case on a Github discussion and we will
integrate it).


Coding conventions
==================

- Use [ocp-indent](https://github.com/OCamlPro/ocp-indent) to indent files;

- Avoid trailing whitespaces;

- Avoid using tabs;

- Strive to keep within 80 characters per line.

Note that many files are not normalized, since they were written before these
conventions were established. However, modified code that touches lines that
are not normalized should be normalized (e.g., if you modify a line containing
trailing whitespace, remove it in your commit). Avoid commits that only
re-indent/prettify code.


External plug-ins
=================

Frama-C plug-ins normally do not require changes to the Frama-C source code and
can be developed completely independently, for instance in a dedicated Git
repository.

However, to make it easier for your users to compile and use your plug-in, even
as newer releases are made available, we recommend the following workflow:

1. Clone the Frama-C snapshot repository;

2. Put your plugin in the `src/plugins` directory, with appropriate
   `configure.ac` and `Makefile.in` files;

3. Upload it to Github.

This will ensure that (1) the version of Frama-C that is available with your
plug-in is guaranteed to compile and work, independently of API changes;
(2) updating your plug-in will only require synchronizing with the
Frama-C snapshot repository.
