## Dome Framework Guides

- [Dome Framework](guides/dome.md.html)
- [Quick Start](guides/quickstart.md.html)
- [Live Editing](guides/hotreload.md.html)
- [Application Design](guides/application.md.html)
- [Application Development](guides/development.md.html)
- [Styling Components](guides/styling.md.html)
- [Custom Hooks](guides/hooks.md.html)
- [Icon Gallery](guides/icons.md.html)
- [Glossary](guides/glossary.md.html)

## Setup

From the `./ivette` sub-directory of Frama-C main directory:

```
$ make app
```

## Typescript Editors

Emacs mode configuration can be setup with Typescript, Web-mode and Tide packages
which are all available with MELPA. For configuring your `.emacs` accordingly,
please look at the `share/typescript-config.el` file.
This setup the Tide package to work with
`typescript-mode` for `*.ts` files (see also `tsfmt.json` config file)
and `web-mode` for `*.tsx` files.

VS-Code is also known to work out of the box.

## Coding Guidelines

- per-directory `style.css` for CSS;
- caml-cased file names for typescript modules;
- indentation based on 2 spaces, no tabs;
- caml-case identifiers for exported members;
- no `export default` for libs, individual exports only;
- prefer use of `import * as AbcDef from '<path>/AbcDef'`;

## Mirroring to Dome/Electron

The content of ./src/dome shall be kept in sync with
the public repository for Dome. An experimental support
for automated synchronisation is available with:
- `make dome-pull` for pulling Dome updates into Ivette
- `make dome-push` for pushing local updates into Dome
