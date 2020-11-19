FROM debian:buster as base

# Install non-OCaml dependencies + opam
RUN apt-get update && apt-get install -y \
    cvc4 \
    opam \
    z3 \
    && rm -rf /var/lib/apt/lists/*

RUN opam init --disable-sandboxing --compiler=ocaml-base-compiler.4.05.0 -y

# "RUN eval $(opam env)" does not work, so we manually set its variables
ENV OPAM_SWITCH_PREFIX "/root/.opam/ocaml-base-compiler.4.05.0"
ENV CAML_LD_LIBRARY_PATH "/root/.opam/ocaml-base-compiler.4.05.0/lib/stublibs:/root/.opam/ocaml-base-compiler.4.05.0/lib/ocaml/stublibs:/root/.opam/ocaml-base-compiler.4.05.0/lib/ocaml"
ENV OCAML_TOPLEVEL_PATH "/root/.opam/ocaml-base-compiler.4.05.0/lib/toplevel"
ENV MANPATH "$MANPATH:/root/.opam/ocaml-base-compiler.4.05.0/man"
ENV PATH "/root/.opam/ocaml-base-compiler.4.05.0/bin:$PATH"

RUN opam update -y && opam install depext -y

# Install packages from reference configuration
RUN apt-get update && opam update -y && opam depext --install -y --verbose \
    alt-ergo-free.2.0.0 \
    apron.20160125 \
    conf-graphviz.0.1 \
    mlgmpidl.1.2.9 \
    ocamlfind.1.8.0 \
    ocamlgraph.1.8.8 \
    why3.1.2.0 \
    yojson.1.4.1 \
    zarith.1.7 \
    && rm -rf /var/lib/apt/lists/*

RUN why3 config --detect-provers

# with_source: keep Frama-C sources
ARG with_source=no

RUN cd /root && \
    wget http://frama-c.com/download/frama-c-19.1-Potassium.tar.gz && \
    tar xvf frama-c-*.tar.gz && \
    (cd frama-c-* && \
        ./configure --disable-gui && \
        make -j && \
        make install \
    ) && \
    rm -f frama-c-*.tar.gz && \
    [ "${with_source}" != "no" ] || rm -rf frama-c-*

# with_test: run Frama-C tests; requires "with_source=yes"
ARG with_test=no

RUN if [ "${with_test}" != "no" ]; then \
       apt-get update && \
       opam update -y && opam depext --install -y \
           conf-python-3.1.0.0 \
           conf-time.1 \
           --verbose \
        && \
        rm -rf /var/lib/apt/lists/* && \
        cd /root/frama-c-* && \
        make tests; \
    fi
