# MERCE

GIT project for our collaboration with MERCE


## Project Members

Allan Blanchard
Loïc Correnson
Tristan Le Gall
Jan Rochel
Julien Signoles

## Building

This plug-in requires the library 'unionFind' that can be installed as follows:
  opam install unionFind

To build with profiling install the package landmarks-ppx and run:
  dune build --instrument-with landmarks

Using the plugin will then echo profiling information to stderr.
