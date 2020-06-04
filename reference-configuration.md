The following set of packages is known to be a working configuration for
compiling Frama-C 21 (Scandium), on a machine with gcc <= 9[^gcc-10]

- OCaml 4.07.1
- ocamlfind.1.8.0
- apron.v0.9.12 (optional)
- lablgtk.2.18.10 | lablgtk3.3.0.beta6 + lablgtk3-sourceview3.3.0.beta6
- mlgmpidl.1.2.12 (optional)
- ocamlgraph.1.8.8
- why3.1.3.1
- alt-ergo.2.0.0 (for wp, optional)
- yojson.1.7.0
- zarith.1.9.1
- zmq.5.1.3 (for server, optional)

[^gcc-10]: As mentioned in this [OCaml PR](https://github.com/ocaml/ocaml/issues/9144)
gcc 10 changed its default linking conventions to make them more stringent,
resulting in various linking issues. In particular, only OCaml 4.10 can be
linked against gcc-10. With respect to the list above, this also means using
ocamlfind.1.8.1 and the development version of lablgtk (https://github.com/garrigue/lablgtk)