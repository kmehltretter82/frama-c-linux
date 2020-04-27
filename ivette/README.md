## Setup

From the `./gui` sub-directory of Frama-C main directory:

```
$ make app
```

## Typescript & Emacs

Emacs mode configuration can be setup with Typescript, Web-mode and Tide packages
which are all available with MELPA. For configuring your `.emacs` accordingly,
please look at the [EMACS](./EMACS.el) file.

## Mirroring to Dome/Electron

The content of ./src/dome shall be kept in sync with
the public repository for Dome. An experimental support
for automated synchronisation is available with:
- `make dome-pull` for pulling Dome updates into Ivette
- `make dome-push` for pushing local updates into Dome
