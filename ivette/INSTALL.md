# Dependencies

Required package to be installed:
- `yarn` for node pakage management;
- `pandoc` for generating the documentation;

# Installation

From the `Frama-C` main directory, simply type:

```
$ make -C ivette dist
```

If this is the first time you compile `ivette`, this might take some time to download
all the necessary packages and Electron binaries from the web.

Once finished, the Ivette application is available in `ivette/dist/<platform>` directory.

# Developer Install

Ivette can be compiled and used with different modes:
- `make dev` builds and start the development version with live-code-editing enabled. It uses
  local binaries of Electron framework. This is _not_ a full packaged
  application.
- `make app` pre-builds the production application. It is not _yet_ packaged and still
  uses the local Electron binaries.
- `make dist` packages the pre-built application into a new application for the host
  operating system.

The development and production applications can be launched from the command line
with `Frama-C/ivette/bin/frama-c-gui` binary.
The generated `frama-c-gui` script will use the local `Frama-C/bin/frama-c` binary by default,
although you can change the default settings by using the following options:

```
frama-c-gui [ivette options] [frama-c command line]
  --cwd <dir> change the working directory used by ivette & frama-c
  --command <bin> set the frama-c server to be launched
  --socket <socket> set the IPC socket name to be used for the frama-c server
```

See also the [CONTRIBUTING] guide for editor configuration if you want to hack in Ivette
source code.
