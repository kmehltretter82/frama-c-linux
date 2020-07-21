Docker images for Frama-C
=========================

- To build a new image (slim, without Frama-C sources nor tests):

        cd <tag>
        docker build . --target base -t framac/frama-c:<tag>

- To run an interactive shell:

        docker run -it framac/frama-c:<tag>

- To push to Docker Hub (requires access to the `framac/frama-c` repository):

        docker push framac/frama-c:<tag>

- To build an image containing Frama-C sources (downloaded from the .tar.gz, in
  directory `/root`):

        cd <tag>
        docker build . --build-arg with_source=yes \
          -t framac/frama-c:<tag>-with-source

- To run Frama-C tests (and remove unnecessary image later):

        cd <tag>
        docker build . --build-arg with_source=yes --build-arg with_test=yes \
          -t framac/frama-c:<tag>-with-test
        docker image rm framac/frama-c:<tag>-with-test
