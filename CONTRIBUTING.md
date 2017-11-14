Contributing to Frama-C
=======================

We always welcome technical as well as non-technical contributions from the
community.
There are several ways to participate in the Frama-C project:

- Asking questions and discussing at
  [StackOverflow](https://stackoverflow.com/tags/frama-c) and through
  the
  [Frama-C-discuss mailing list](https://lists.gforge.inria.fr/mailman/listinfo/frama-c-discuss);

- Reporting bugs (via
  [Github issues](https://github.com/Frama-C/Frama-C-snapshot/issues)) or the
  [Mantis BTS](https://bts.frama-c.com);

- [Submitting bug fixes, improvements, and features](#submitted-bug-fixes-improvements-and-features)
  via Github pull requests;

- [Developing your own plug-in](#external-plug-ins)
  and sharing it with us through a Github pull request;

- Joining the [Frama-C team](http://frama-c.com/about.html) (as an intern, a PhD
  student, a postdoctoral researcher, or a research engineer).

We give below some guidelines in order to ease the submission of a pull request
and optimize its integration with the Frama-C existing codebase.


Submitted bug fixes, improvements, and features
===============================================

Main Frama-C development happens outside Github. By default, patches and
improvements are applied upstream and only release candidates and stable
releases are pushed to Github.

Therefore, your pull requests will not be directly merged in the `master` branch
on Github. Instead, we will port them in our internal development platform and
they will be available on Github after the next Frama-C release incorporates
them.

To fit this workflow, we recommend to:

1. [Prepare to sign the CLA (Contributor License Agreement)](#contributor-license-agreement-cla)
  if your contribution does not fall under the
  [TCE (Trivial Contribution Exemption)](#trivial-contribution-exemption-tce).

2. [Open an issue](https://github.com/Frama-C/Frama-C-snapshot/issues/new)
  describing your contribution.

3. [Fork the Frama-C snapshot repository](https://github.com/Frama-C/Frama-C-snapshot/fork)
  (choosing your Github account as a destination);

4. Clone the forked Frama-C snapshot repository on your computer by typing
  ```shell
  git clone https://github.com/username/Frama-C-snapshot.git
  ```
  in your terminal (change `username` by your Github username);

5. Create and switch in a dedicated branch by typing 
  ```shell
  git checkout -b branch-name
  ```
  in your terminal (change `branch-name` by your chosen branch name). The chosen
  branch name should follow the following convention:
  - `bugfix/username/short-description` for bug fixes (correcting an incorrect
  behaviour);
  - `improv/username/short-description` for improvements (making even better a
  functionnally correct behaviour);
  - `feature/username/short-description` for features (adding a new behaviour).

6. Locally make your contribution by adding/editing/deleting files and following
  the [coding conventions](#coding-conventions);

7. Optionnally locally add non-regression test cases to the appropriate
  subdirectory in `./tests/`. The
  [plug-in developer manual](http://frama-c.com/download/frama-c-plugin-development-guide.pdf)
  exemplifies the use of the dedicated `ptests` tool used by Frama-C developers
  in its `hello` tutorial and provides a documentation of it in a full section.
  You can also provide the non-regression test case in the Github issue
  discussion and we will integrate it).

8. Check for unexpected changes (in particular spaces and tabulations) by typing
  ```shell
  git diff --check
  ```
  in your terminal.

9. Locally run the test framework of Frama-C by typing
  ```shell
  make tests
  ```
  in your terminal (you should be in the Frama-C root directory);

10. Locally add (if needed) and commit your contribution by typing
  ```shell
  git add -A
  git commit -m "Commit message (GH#XXX)"
  ```
  in your terminal (this adds all the new files to the commit, you can pick the
  relevant files as described in the
  [`Git` documentation](https://git-scm.com/docs/git-add)). The end of the
  commit message should refer the Github issue to which this commit is linked
  and thus #XXX replaced by the corresponding number;

11. Push your contribution to Github by typing
  ```shell
  git push origin branch-name
  ```
  in your terminal (change `branch-name` by the right branch name);

12. [Make a Github pull request](https://github.com/Frama-C/Frama-C-snapshot/compare)
  (toggling the `compare across forks` view). The base fork should remain as
  `Frama-C/Frama-C-snapshot` and the base as `master` while the head fork
  should be yours and the compare should be your chosen branch name.

Coding conventions
==================

- Use [ocp-indent](https://github.com/OCamlPro/ocp-indent) to indent files;

- Avoid trailing whitespaces;

- Avoid using tabs;

- Strive to keep within 80 characters per line.

Note that many files are not normalized, since they were written before these
conventions were established. However, modified code that touches lines that
are not normalized should be normalized (e.g., if you modify a line containing
a trailing whitespace, remove it in your commit). Avoid commits that only
re-indent/prettify code.


External plug-ins
=================

Frama-C is a modular platform for which it is possible to develop external
plug-ins as documented in the
[Plug-in Development Guide](http://frama-c.com/download/frama-c-plugin-development-guide.pdf).
Such plug-ins normally do not require changes to the Frama-C source code and can
be developed completely independently, for instance in a separate Git
repository.

However, to make it easier for your users to compile and use your plug-in, even
as newer releases are made available, we recommend the following workflow:

1. [Fork the Frama-C snapshot repository](https://github.com/Frama-C/Frama-C-snapshot/fork)
  (choosing your Github account as a destination);

2. Clone the forked Frama-C snapshot repository on your computer by typing
  ```shell
  git clone https://github.com/username/Frama-C-snapshot.git
  ```
  in your terminal (change `username` by your Github username);

3. Locally make your contribution by adding/editing/deleting files in the
  `./src/plugins/` directory, along with appropriate
   `configure.ac` and `Makefile.in` files, and following
  the [coding conventions](#coding-conventions);

4. Optionnally locally add non-regression test cases to the appropriate
  subdirectory in `./tests/`. The
  [plug-in developer manual](http://frama-c.com/download/frama-c-plugin-development-guide.pdf)
  exemplifies the use of the dedicated `ptests` tool used by Frama-C developers
  in its `hello` tutorial and provides a documentation of it in a full section.
  You can also provide the non-regression test case in the Github issue
  discussion and we will integrate it).

5. Locally run the test framework of Frama-C by typing
  ```shell
  make tests
  ```
  in your terminal (you should be in the Frama-C root directory);

6. Locally add (if needed) and commit your contribution by typing
  ```shell
  git add -A
  git commit -m "Commit message"
  ```
  in your terminal (this adds all the new files to the commit, you can pick the
  relevant files as described in the
  [`Git` documentation](https://git-scm.com/docs/git-add));

7. Push your contribution to Github by typing
  ```shell
  git push -u origin branch-name
  ```
  in your terminal (change `branch-name` by the right branch name).

This will ensure that (1) the version of Frama-C that is available with your
plug-in is guaranteed to compile and work, independently of API changes;
(2) updating your plug-in will only require synchronizing with the
Frama-C snapshot repository.


Contributor License Agreement (CLA)
===================================

TODO

Trivial Contribution Exemption (TCE)
====================================

TODO