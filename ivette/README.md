## Ivette

Main entry points:
- [frama-c/server](modules/frama_c_server.html) Frama-C Server interaction (low level)
- [frama-c/states](modules/frama_c_states.html) high-level request management

## Command Line

The following options are recognized by `./bin/frama-c-gui`:

- `--cwd` working directory of Frama-C server
- `--command` path to Frama-C binary
- `--socket` ZeroMQ socket address of the server

The default working directory is the current one.
The default command is the local `bin/frama-c` of source installation.
The default socket is `ipc:///.frama-c.<pid>.io`.

## Dome Guides

- [Dome Framework](guides/dome.md.html)
- [Quick Start](guides/quickstart.md.html)
- [Live Editing](guides/hotreload.md.html)
- [Application Design](guides/application.md.html)
- [Application Development](guides/development.md.html)
- [Styling Components](guides/styling.md.html)
- [Custom Hooks](guides/hooks.md.html)
- [Icon Gallery](guides/icons.md.html)
- [Glossary](guides/glossary.md.html)
