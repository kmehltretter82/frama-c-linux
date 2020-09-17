Building a Frama-C Docker image with a custom git clone
=========================================================================

In order to build a Frama-C Docker image with custom plug-ins, or using
a custom git repository, do the following:

1. Locally clone Frama-C into the `frama-c` directory, e.g. via

        git clone git@frama-c.com:frama-c/frama-c.git

   If needed, modify the clone to add other plug-ins and/or files inside
   `frama-c`.

2. If needed, add Debian and opam prerequisites to the appropriate lines in the
   Dockerfile, or change the opam version in the `ENV` lines.

3. For a "minimal" image (with installed Frama-C, but no source code), run:

        docker build . -t fc-custom # or another tag if you prefer

    For an image with the Frama-C source code (in `/root/frama-c`), run:

        docker build . -t fc-custom-with-source --build-arg=with_source=yes

    For an image with source code + tests (e.g. which runs `make tests`), run:

        docker build . -t fc-custom-with-test --build-arg=with_source=yes --build-arg=with_test=yes

4. In all cases, after building the image, run it with:

        docker run -it fc-custom # or another tag

Frama-C will be installed and its sources will be in `/root/frama-c`.

### Notes

1. If you keep the sources, remember that the Docker image may contain
   non-public code.

2. Using different tags for the `*-with-source` and `*-with-test` images may
   allow layer reuse by Docker.

3. If you need files outside `/root/frama-c`, add them to the directory
   containing this README and add a `COPY` instruction to the `Dockerfile`,
   e.g. `COPY dir /root/dir`.
