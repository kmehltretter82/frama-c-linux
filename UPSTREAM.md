# Upstream and repository history

The canonical Frama-C repository is:

<https://git.frama-c.com/pub/frama-c.git>

The GitHub history in this repository is intentionally filtered. Canonical
Frama-C history contains generated E-ACSL benchmark artifacts larger than
GitHub's object limit. During the initial import, all historical blobs larger
than 50 MiB were removed. Two known benchmark paths were also removed across
their complete history:

```text
src/plugins/e-acsl/tests/csrv14/Team1/Bench3/Debug/flows.0607.dat
src/plugins/e-acsl/tests/csrv14/Team1/Bench5/Debug/test10.txt.tar.gz
```

Filtering rewrites commit and annotated-tag identifiers. It does not change the
current source tree: at import time both repositories had the tree object
`5eb15fc039c90a4511469c9aa28173936553d8b2`.

The initial head mapping is:

```text
official: 0340f258e91052af7d2326cb4c76cc338754a5ca
filtered: f4f81ad90173f9b88bf142118ba28fd0255123ce
```

## Branches

- `upstream-clean` tracks the filtered form of official Frama-C development
  history.
- `main` contains Frama-C Linux changes on top of `upstream-clean`.

Do not merge unfiltered official history directly into `main`; doing so would
reintroduce the oversized objects and mix the canonical and rewritten commit
graphs.

## Reproducing the filter

The initial import used `git-filter-repo` 2.47.0 with these operations, in this
order:

```sh
git filter-repo --force --invert-paths \
  --path src/plugins/e-acsl/tests/csrv14/Team1/Bench3/Debug/flows.0607.dat \
  --path src/plugins/e-acsl/tests/csrv14/Team1/Bench5/Debug/test10.txt.tar.gz
git filter-repo --force --strip-blobs-bigger-than 50M
```

To synchronize, filter a fresh official clone with the same recipe, verify that
the previous `upstream-clean` head is its ancestor, and advance
`upstream-clean`. The downstream `main` branch can then merge or rebase onto
that clean branch. Always compare the official and filtered head tree objects
before publishing the result.
