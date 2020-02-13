## Setup

From the `./gui` sub-directory of Frama-C main directory:

```
$ make app
```

## Mirroring to Dome/Electron

The content of ./src/dome is git-subtree to be kept in sync
with Dome/Electron. The related commands must be issued from
the Frama-C root directory:

1. Importing a branch from dome/electron:

```
$ git subtree pull -P gui/src/dome git@git.frama-c.com:dome/electron.git <branch>
```

2. Exporting to a branch into dome/electron:

```
$ git subtree push -P gui/src/dome git@git.frama-c.com:dome/electron.git <branch>
```
