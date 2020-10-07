The following set of packages is known to be a working configuration for
compiling Frama-C+dev, on a machine with gcc <= 9[^gcc-10]

- OCaml 4.08.1
- alt-ergo.2.2.0 (for wp, optional)
- apron.v0.9.12 (for eva, optional)
- lablgtk.2.18.11 | lablgtk3.3.1.1 + lablgtk3-sourceview3.3.1.1
- mlgmpidl.1.2.12 (for eva, optional)
- ocamlfind.1.8.1
- ocamlgraph.1.8.8
- ppx_deriving_yojson.3.5.2 (for mdr, optional)
- why3.1.3.3
- yojson.1.7.0
- zarith.1.9.1
- zmq.5.1.3 (for server, optional)

[^gcc-10]: As mentioned in this [OCaml PR](https://github.com/ocaml/ocaml/issues/9144)
gcc 10 changed its default linking conventions to make them more stringent,
resulting in various linking issues. In particular, only OCaml 4.10 can be
linked against gcc-10.
