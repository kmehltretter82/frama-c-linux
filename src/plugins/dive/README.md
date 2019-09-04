Dive is a Frama-C plugin, specialized into the visualization of data
dependencies. The main goal of this visualization is to help the user to find
the origin of an imprecision of an Eva analysis.


Some jargon
===========

The front-end of Dive relies on several external tools and libraries :

- Node.js: a runtime environment for javascript to run programs outside a
  browser
- yarn: a package manager for javascript modules written for Node.js
- electron: a javascript framework for gui applications
- Ivette: the future Frama-C and other tools GUI
- Cytoscape: a javascript library to display graphs and interact with them
- Zmq: a multilanguage framework for common simple networking patterns


Compilation
===========

Dependencies
------------

- Zmq must be installed with opam (with its system dependencies) for the
  `-server-zmq` option to be available.


Instructions
------------

The Frama-C plugin can be cloned into the Frama-C plugin source directory.

```bash
cd framac/src/plugins
git clone git@git.frama-c.com:frama-c/dive.git
```

The front-end is, for now, completely independent. One must start by cloning
Dome-electron, on the branch `feature/cytoscape`. Dome-electron provides a
framework to develop and test Ivette visual components.

```bash
git clone git@git.frama-c.com:dome/electron.git --branch feature/cytoscape
```

In the electron directory, install a few javascript libraries needed by Dive.

```bash
cd electron
yarn add --dev @fortawesome/fontawesome-free cytoscape-cxtmenu cytoscape \
  cytoscape-popper tippy.js cytoscape-dagre cytoscape-cola \
  cytoscape-cose-bilkent cytoscape-klay
```

You can then run the framework for the first time by using the `dev` target
of the `Makefile`.

```bash
make dev
```

At the end of the (long) process, it should open a window with an Hello-World
application. We will now replace this application with Dive. You can leave the
electron application running. Inside the `src/renderer` directory, clone the
front-end component of Dive.

```bash
cd src/renderer
git clone git@git.frama-c.com:perrelle/dive-electron.git
```

Finally, edit the contents of `src/renderer/App.js` and replace it by

```javascript
import dive from './dive-electron/main.js';

export default dive;
```

The application in the window should automatically update after a while.


Usage
=====

Once compiled, the Dome front-end component will always be displayed when
typing

```bash
make dev
```

and will try to connect to a Frama-C server on `tcp://127.0.0.1:9000`.

Frama-C can be lauched before or after, either directly

```bash
frama-c source.c -server-zmq tcp://127.0.0.1:9000
```

or, if the analysis results have been previously recorded

```bash
frama-c -load results.sav -server-zmq tcp://127.0.0.1:9000
```
