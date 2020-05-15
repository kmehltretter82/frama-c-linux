## Coding Guidelines

- use `make app` (checked by GitLab-CI)
- per-directory `style.css` for CSS;
- caml-cased file names for typescript modules;
- indentation based on 2 spaces, no tabs;
- caml-case identifiers for exported members;
- no `export default` for libs, individual exports only;
- prefer use of `import * as AbcDef from '<path>/AbcDef'`;

## Makefile Targets

From the `./ivette` sub-directory of Frama-C main directory:

```
$ make app  // Builds desktop app
$ make dev  // Launch development version with live code editing
$ make doc  // Generate development documentation (static)
$ make serve // Serve the documentation (makes it searchable)
```

Once build, the application can be launched from the command line
with `./bin/frama-c-gui`.

The static documentation is available offline at `doc/html/index.html`.
However, searching the documentation does not work
with `file://` protocole, use `make serve` to use it.

## Mirroring to Dome/Electron

**Warning:** not recommanded until all codebase has been moved to TypeScript.

The content of ./src/dome shall be kept in sync with
the public repository for Dome. An experimental support
for automated synchronisation is available with:
- `make dome-pull` for pulling Dome updates into Ivette
- `make dome-push` for pushing local updates into Dome
