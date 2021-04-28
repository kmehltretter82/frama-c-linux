# Emacs Configuration

Emacs mode configuration can be setup with Typescript, Web-mode and Tide packages.
You can install them with `M-x package-install`:

```
M-x package-refresh-contents ;; updates your index
M-x package-install web-mode
M-x package-install typescript-mode
M-x package-install tidse
```

For configuring your `.emacs` accordingly,
please look at the `share/typescript-config.el` file.
It setup the Tide package to work with
`typescript-mode` for `*.ts` files (see also `tsfmt.json` config file)
and `web-mode` for `*.tsx` files.

Usefull commands:

```
M-. goto definition
M-, back to previous point
M-x tide-documentation-at-point
M-x tide-error-at-point
```

# VS Code

VS Code has native support for Typescript (and JavaScript, of course), in terms
of code navigation, syntax highlighting and formatting, compiler errors and
warnings. The same holds for React development.

Useful extensions:
- `ESlint` provides support for lint errors and warnings;
- `ES7 React/Redux/GraphQL/React-Native snippets` provides boilerplate snippets;
