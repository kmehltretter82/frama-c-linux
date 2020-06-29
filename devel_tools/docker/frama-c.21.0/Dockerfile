FROM debian:sid as base

RUN apt update
RUN apt install opam -y
RUN opam init --disable-sandboxing --compiler=ocaml-base-compiler.4.07.1 -y

# "RUN eval $(opam env)" does not work, so we manually set its variables
ENV OPAM_SWITCH_PREFIX "/root/.opam/ocaml-base-compiler.4.07.1"
ENV CAML_LD_LIBRARY_PATH "/root/.opam/ocaml-base-compiler.4.07.1/lib/stublibs:/root/.opam/ocaml-base-compiler.4.07.1/lib/ocaml/stublibs:/root/.opam/ocaml-base-compiler.4.07.1/lib/ocaml"
ENV OCAML_TOPLEVEL_PATH "/root/.opam/ocaml-base-compiler.4.07.1/lib/toplevel"
ENV MANPATH "$MANPATH:/root/.opam/ocaml-base-compiler.4.07.1/man"
ENV PATH "/root/.opam/ocaml-base-compiler.4.07.1/bin:$PATH"

RUN opam update -y
RUN opam install depext -y

# Install packages from reference configuration
RUN opam depext --install -y \
    alt-ergo.2.0.0 \
    apron.v0.9.12 \
    conf-graphviz.0.1 \
    mlgmpidl.1.2.12 \
    ocamlfind.1.8.0 \
    ocamlgraph.1.8.8 \
    ppx_deriving_yojson.3.5.2 \
    why3.1.3.1 \
    yojson.1.7.0 \
    zarith.1.9.1 \
    zmq.5.1.3 \
    --verbose # intentionally left as last line in this RUN command
RUN why3 config --full-config

# with_source: keep Frama-C sources
ARG with_source=no

RUN cd /root && \
    wget http://frama-c.com/download/frama-c-21.0-Scandium.tar.gz && \
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
       opam depext --install -y \
           conf-python-3.1.0.0 \
           conf-time.1 \
           --verbose \
        && \
        cd /root/frama-c-* && \
        make tests; \
    fi
