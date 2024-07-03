In all these tests please set HOME before executing commands so that it does not
touch the actual user HOME.

  $ dune build --root . @install

Basic case
  $ HOME=home dune exec -- frama-c
  [dirs] Warning: created cache directory `home/.cache/frama-c/dirs/created'
  [dirs] Warning: created config directory `home/.config/frama-c/dirs/created'
  [dirs] Warning: created state directory `home/.local/state/frama-c/dirs/created'
  [dirs] Warning: created session directory `.frama-c/dirs/created'
  [dirs] Warning: created session directory `.frama-c/dirs/created_filepath'
  [dirs] Not created:
  [dirs] home/.cache/frama-c/dirs/not_created
  [dirs] home/.config/frama-c/dirs/not_created
  [dirs] home/.local/state/frama-c/dirs/not_created
  [dirs] .frama-c/dirs/not_created
  [dirs] .frama-c/dirs/not_created_filepath/file
  $ find home
  home
  home/.cache
  home/.cache/frama-c
  home/.cache/frama-c/dirs
  home/.cache/frama-c/dirs/created
  home/.local
  home/.local/state
  home/.local/state/frama-c
  home/.local/state/frama-c/dirs
  home/.local/state/frama-c/dirs/created
  home/.config
  home/.config/frama-c
  home/.config/frama-c/dirs
  home/.config/frama-c/dirs/created
  $ rm -rf home

Customized via variables: XDG level
  $ HOME=home XDG_CACHE_HOME=cache XDG_CONFIG_HOME=config XDG_STATE_HOME=state dune exec -- frama-c
  [dirs] Warning: created cache directory `cache/frama-c/dirs/created'
  [dirs] Warning: created config directory `config/frama-c/dirs/created'
  [dirs] Warning: created state directory `state/frama-c/dirs/created'
  [dirs] Not created:
  [dirs] cache/frama-c/dirs/not_created
  [dirs] config/frama-c/dirs/not_created
  [dirs] state/frama-c/dirs/not_created
  [dirs] .frama-c/dirs/not_created
  [dirs] .frama-c/dirs/not_created_filepath/file
  $ find home
  find: 'home': No such file or directory
  [1]
  $ find cache
  cache
  cache/frama-c
  cache/frama-c/dirs
  cache/frama-c/dirs/created
  $ find config
  config
  config/frama-c
  config/frama-c/dirs
  config/frama-c/dirs/created
  $ find state
  state
  state/frama-c
  state/frama-c/dirs
  state/frama-c/dirs/created
  $ rm -rf home cache config state

Customized via variables: Kernel level
  $ HOME=home FRAMAC_CACHE=cache FRAMAC_CONFIG=config FRAMAC_STATE=state FRAMAC_SESSION=session dune exec -- frama-c
  [dirs] Warning: created cache directory `cache/dirs/created'
  [dirs] Warning: created config directory `config/dirs/created'
  [dirs] Warning: created state directory `state/dirs/created'
  [dirs] Warning: created session directory `session/dirs/created'
  [dirs] Warning: created session directory `session/dirs/created_filepath'
  [dirs] Not created:
  [dirs] cache/dirs/not_created
  [dirs] config/dirs/not_created
  [dirs] state/dirs/not_created
  [dirs] session/dirs/not_created
  [dirs] session/dirs/not_created_filepath/file
  $ find home
  find: 'home': No such file or directory
  [1]
  $ find cache
  cache
  cache/dirs
  cache/dirs/created
  $ find config
  config
  config/dirs
  config/dirs/created
  $ find state
  state
  state/dirs
  state/dirs/created
  $ rm -rf home cache config state

Customized via variables: Plugin level
  $ HOME=home FRAMAC_DIRS_CACHE=cache FRAMAC_DIRS_CONFIG=config FRAMAC_DIRS_STATE=state FRAMAC_DIRS_SESSION=session dune exec -- frama-c
  [dirs] Warning: created cache directory `cache/created'
  [dirs] Warning: created config directory `config/created'
  [dirs] Warning: created state directory `state/created'
  [dirs] Warning: created session directory `session/created'
  [dirs] Warning: created session directory `session/created_filepath'
  [dirs] Not created:
  [dirs] cache/not_created
  [dirs] config/not_created
  [dirs] state/not_created
  [dirs] session/not_created
  [dirs] session/not_created_filepath/file
  $ find home
  find: 'home': No such file or directory
  [1]
  $ find cache
  cache
  cache/created
  $ find config
  config
  config/created
  $ find state
  state
  state/created
  $ rm -rf home cache config state

Customized via options kernel level
  $ HOME=home dune exec -- frama-c -cache cache -config config -state state -session session
  [dirs] Warning: created cache directory `cache/dirs/created'
  [dirs] Warning: created config directory `config/dirs/created'
  [dirs] Warning: created state directory `state/dirs/created'
  [dirs] Not created:
  [dirs] cache/dirs/not_created
  [dirs] config/dirs/not_created
  [dirs] state/dirs/not_created
  [dirs] session/dirs/not_created
  [dirs] session/dirs/not_created_filepath/file
  $ find home
  find: 'home': No such file or directory
  [1]
  $ find cache
  cache
  cache/dirs
  cache/dirs/created
  $ find config
  config
  config/dirs
  config/dirs/created
  $ find state
  state
  state/dirs
  state/dirs/created
  $ rm -rf home cache config state

Customized via options plug-in level
  $ HOME=home dune exec -- frama-c -dirs-cache cache -dirs-config config -dirs-state state -dirs-session session
  [dirs] Warning: created cache directory `cache/created'
  [dirs] Warning: created config directory `config/created'
  [dirs] Warning: created state directory `state/created'
  [dirs] Not created:
  [dirs] cache/not_created
  [dirs] config/not_created
  [dirs] state/not_created
  [dirs] session/not_created
  [dirs] session/not_created_filepath/file
  $ find home
  find: 'home': No such file or directory
  [1]
  $ find cache
  cache
  cache/created
  $ find config
  config
  config/created
  $ find state
  state
  state/created
  $ rm -rf home cache config state

Customized plug-in option > plug-in var
  $ HOME=home FRAMAC_DIRS_CACHE=cache_bad dune exec -- frama-c -dirs-cache-only -dirs-cache cache
  [dirs] Warning: created cache directory `cache/created'
  $ rm -rf home cache

Customized plug-in var > kernel option
  $ HOME=home FRAMAC_DIRS_CACHE=cache dune exec -- frama-c -dirs-cache-only -cache cache_bad
  [dirs] Warning: created cache directory `cache/created'
  $ rm -rf home cache

Customized kernel option > kernel var
  $ HOME=home FRAMAC_CACHE=cache_bad dune exec -- frama-c -dirs-cache-only -cache cache
  [dirs] Warning: created cache directory `cache/dirs/created'
  $ rm -rf home cache

Customized kernel var > xdg var
  $ HOME=home XDG_CACHE_HOME=cache_bad FRAMAC_CACHE=cache dune exec -- frama-c -dirs-cache-only
  [dirs] Warning: created cache directory `cache/dirs/created'
  $ rm -rf home cache

Bad home value
  $ HOME= dune exec -- frama-c
  [dirs] User Error: Failure when creating directories
  [dirs] User Error: Deferred error message was emitted during execution. See above messages for more information.
  [kernel] Plug-in dirs aborted: invalid user input.
  [1]

Bad home permission
  $ mkdir home
  $ chmod -w home
  $ HOME=home dune exec -- frama-c
  [dirs] User Error: cannot create cache directory `home/.cache/frama-c/dirs/created'
  [kernel] Plug-in dirs aborted: invalid user input.
  [1]
  $ rm -rf home

File already exists were a directory is expected
  $ mkdir cache
  $ touch cache/created
  $ HOME=home dune exec -- frama-c -dirs-cache cache
  [dirs] User Error: cannot create directory as file cache/created already exists
  [kernel] Plug-in dirs aborted: invalid user input.
  [1]
  $ rm -rf cache
