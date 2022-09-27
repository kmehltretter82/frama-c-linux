# Frama-C Docker images

Frama-C Docker images are currently based on Alpine Linux.

The user is `opam` and it has sudo rights.

To add Alpine packages, run `sudo apk add <package>`.

An OCaml switch is set up with the packages mentioned in
`reference-configuration.md`, plus a few external SMT solvers
(CVC4, Z3).

There are 2 main images, each with 3 variants:

- `dev` image: based on the public Frama-C git repository;
- `custom` image: based on a custom .tar.gz archive put in this directory.
  Note: it _must_ be named `frama-c-<something>.tar.gz`, where
  `<something>` may be a version number, codename, etc.
  It _must_ be put in this directory.

Each of these is declined in 3 variants:

- standard (no suffix): an image with the command line `frama-c` version,
  without GUI;
- `-gui`: the standard image + `frama-c-gui`. To be used with Singularity,
  x11docker, or any other tool which enables running a graphical application
  from a Docker image.
- `-stripped`: the standard image reduced to a minimal set of files, for
  smaller size. Note: this image has several files removed, rendering some
  non-essential components unusable.

Note that only _some_ usages of Frama-C have been tested; notify us if your
intended plug-in or usage scenario does not work (and is not listed in the
*Known issues* below).

## Known issues

- E-ACSL does not currently work in these images: its `musl` libc does not
  contain some debugging information required by E-ACSL.
- The `-stripped` variants no longer have a working OCaml compiler;
  loading some modules or compiling plug-ins may not work.

## Built images

The `dev`: images are tagged with their default names in the Docker Hub:
`framac/frama-c:dev`, `framac/frama-c-gui:dev`, `framac/frama-c:dev-stripped`.

The `custom` images are tagged with prefix `frama-c-custom`, since they are
intended for local usage.

## Helpful commands

- Start Singularity instance

        singularity instance start docker-daemon:framac/frama-c-gui:dev <instance name>

- Run command with Singularity instance

        singularity exec instance://<instance name> <command with args>
