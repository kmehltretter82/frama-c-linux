## Setup

From the `./ivette` sub-directory of Frama-C main directory:

```
$ make app
```

## Typescript Editors

Emacs mode configuration can be setup with Typescript, Web-mode and Tide packages
which are all available with MELPA. For configuring your `.emacs` accordingly,
please look at the `EMACS.el`. This setup the Tide package to work with
`typescript-mode` for `*.ts` files (see also `tsfmt.json` config file)
and `web-mode` for `*.tsx` files.

VS-Code is also known to work out of the box.

## Mirroring to Dome/Electron

The content of ./src/dome shall be kept in sync with
the public repository for Dome. An experimental support
for automated synchronisation is available with:
- `make dome-pull` for pulling Dome updates into Ivette
- `make dome-push` for pushing local updates into Dome
