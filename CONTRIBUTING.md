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

- [Submitting bug fixes, improvements, and features](#submitting-bug-fixes-improvements-and-features)
  via Github pull requests;

- [Developing external plug-ins](#developing-external-plug-ins)
  and sharing it with us through a Github pull request;

- Joining the [Frama-C team](http://frama-c.com/about.html) (as an intern, a PhD
  student, a postdoctoral researcher, or a research engineer).

We give below some guidelines in order to ease the submission of a pull request
and optimize its integration with the Frama-C existing codebase.


Submitting bug fixes, improvements, and features
================================================

Main Frama-C development happens outside Github. By default, patches and
improvements are applied upstream and only release candidates and stable
releases are pushed to Github.

Therefore, your pull requests will not be directly merged in the `master` branch
on Github. Instead, we will port them in our internal development platform and
they will be available on Github after the next Frama-C release incorporates
them.

To fit this workflow, we recommend to:

1. [Open an issue](https://github.com/Frama-C/Frama-C-snapshot/issues/new)
  describing your contribution.

2. [Fork the Frama-C snapshot repository](https://github.com/Frama-C/Frama-C-snapshot/fork)
  (choosing your Github account as a destination);

3. Clone the forked Frama-C snapshot repository on your computer;

4. Create and switch in a dedicated branch which should follow the following convention:
  - `bugfix/username/short-description` for bug fixes (correcting an incorrect
  behaviour);
  - `improv/username/short-description` for improvements (making even better a
  functionnally correct behaviour);
  - `feature/username/short-description` for features (adding a new behaviour).

5. Locally make your contribution by adding/editing/deleting files and following
  the [coding conventions](#coding-conventions);

6. Optionally locally add non-regression test cases to the appropriate
  subdirectory in `./tests/`. The
  [plug-in developer manual](http://frama-c.com/download/frama-c-plugin-development-guide.pdf)
  exemplifies the use of the dedicated `ptests` tool used by Frama-C developers
  in its `hello` tutorial and provides a documentation of it in a full section.
  You can also provide the non-regression test case in the Github issue
  discussion and we will integrate it).

7. Check for unexpected changes (in particular spaces and tabulations);

8. Locally run the test framework of Frama-C by typing
  ```shell
  make tests
  ```
  in your terminal (you should be in the Frama-C root directory);

9. Locally add (if needed) and commit your contribution. The end of the
  commit message should refer to the Github issue to which this commit is
  linked by mentioning its issue identifier preceded by `GH #` (we use the
  `GH` part to track the provenance as we use several issue trackers);

10. Push your contribution to Github;

11. [Make a Github pull request](https://github.com/Frama-C/Frama-C-snapshot/compare)
  (toggling the `compare across forks` view). The base fork should remain as
  `Frama-C/Frama-C-snapshot` and the base as `master` while the head fork
  should be yours and the compare should be your chosen branch name.

For convenience, we recall the typical `git` commands to be used through these steps:
```shell
git clone https://github.com/<username>/Frama-C-snapshot.git
git checkout -b <branch-name>
git diff --check
git add <file1 file 2>
git commit -m "<Commit message> (GH #<XXX>)"
git push origin <branch-name>
```
where:

- `<username>` is your Github username;
- `<branch-name>` is your chosen branch name;
- `<file1 file2>` are the files to add to the commit;
- `<Commit message>` is your commit message;
- `<XXX>` is the Github issue identifier.


Developing external plug-ins
============================

Frama-C is a modular platform for which it is possible to develop external
plug-ins as documented in the
[Plug-In development guide](http://frama-c.com/download/frama-c-plugin-development-guide.pdf).
Such plug-ins normally do not require changes to the Frama-C source code and can
be developed completely independently, for instance in a separate Git
repository as exemplified by the [Hello plug-in](https://github.com/Frama-C/frama-c-hello).

However, to make it easier for your users to compile and use your plug-in, even
as newer releases are made available, we recommend the following workflow:

1. Write your external plug-in as indicated in the
  [Plug-In development guide](http://frama-c.com/download/frama-c-plugin-development-guide.pdf);

2. Create an `opam` package by
  [pinning your local plug-in](http://opam.ocaml.org/doc/Packaging.html#Opam-pin) and
  [editing the `opam` file](http://opam.ocaml.org/doc/Packaging.html#The-quot-opam-quot-file).
  You can have a look at the
  [`opam` file of the Hello plug-in](https://github.com/Frama-C/frama-c-hello/blob/master/opam)
  if necessary.

3. Optionnally
  [publish your plug-in](http://opam.ocaml.org/doc/Packaging.html#Publishing)
  in the official OPAM packages repository.

4. Let know the
  [Frama-C-discuss mailing list](https://lists.gforge.inria.fr/mailman/listinfo/frama-c-discuss)
  about your contribution to the Frama-C ecosystem. Well done!

The main advantage of this way to proceed is the delegation to OPAM of the task
of keeping consistent Frama-C versions and dependencies.


Coding conventions
==================

- Use [ocp-indent](https://github.com/OCamlPro/ocp-indent) to indent files;

- Avoid trailing whitespaces;

- Avoid using tabs;

- Strive to keep within 80 characters per line.