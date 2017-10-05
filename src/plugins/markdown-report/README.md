Generation of pandoc reports.

**Important Note:** Requires OCaml 4.04 or newer (uses a new function from
`String`), instead of the normal 4.02.3 or newer for Frama-C kernel.

# Requirements

- OCaml >= 4.04;
- Frama-C 16 (Phosphorus)
- FlameGraph ([`https://github.com/brendangregg/FlameGraph`](https://github.com/brendangregg/FlameGraph))

# Example

Checking out [`https://github.com/Frama-C/open-source-case-studies`](https://github.com/Frama-C/open-source-case-studies), start with a simple analysis and generate the intermediary SVG and Markdown files.

```shell
frama-c -val 2048.c -val-flamegraph="flamegraph.txt" -save snap.sav
flamegraph.pl ./flamegraph.txt > flamegraph.svg
frama-c -load snap.sav -mdr-gen -mdr-flamegraph="./flamegraph.svg"
```

Then generate a report in your favorite open format:

```shell
pandoc -o report.docx report.md
```
