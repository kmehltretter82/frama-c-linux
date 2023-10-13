This document presents the framework for testing Ivette by describing its
overall architecture, and how to launch current tests and write new ones.

## Overall Architecture

The framework is based on two main testing libraries:

- `Playwright`: <https://playwright.dev/>
- `Gremlins.js`: <https://github.com/marmelab/gremlins.js>

`Playwright` is meant for end-to-end (e2e) testing, i.e. for testing specific
behaviors, while `Gremlins.js` provides monkey testing, i.e. robustness/stress
testing of the entire application.

Here is how the framework is organized:

- `e2e/` contains the end-to-end tests,
- `monkey/` cointains the monkey tests,
- `lib/` contains utilities for writing tests using the `Playwright`
  infrastructure. These utilities are used both for e2e and monkey testing.

## Executing tests

**Requirement:** In order to execute the tests, Frama-C has to be built
beforehand.

Testing Ivette, in terms of both the e2e and monkey tests, amounts to the
execution of the following commands from the Frama-C root directory:

```
$ make                         // builds Frama-C, if not already
$ cd ivette
$ make tests                   // builds Ivette and execute all tests
```

To execute the e2e tests only, the last command to execute is the following:

```
$ make tests-e2e
```

To execute the monkey tests only, the last command to execute is the following:

```
$ make tests-monkey
```

## Executing tests (Advanced)

Whenever the execution of the tests does not need (re-)building Ivette, one can
directly do the following from the Ivette root directory:

```
$ dune exec -- yarn playwright test
```

This is also useful for executing just a (list of) test(s). In such a case, do
the following from the Ivette root directory:

```
$ dune exec -- yarn playwright test /path/to/test1 /path/to/test2
```

For more information, refer to the `Playwright`
[documentation](https://playwright.dev/docs/running-tests).

## Accessing tests report

Upon a test failure, `Playwright` informs about the failing step, or assertion,
with a message on the console. This should be sufficient to debug the failure.
However, `Playwright` also writes down a report of the failure that can be
accessed as follows from the Ivette root directory:

```
$ yarn playwright show-report
```

The previous command should open a browser tab showing the last recorded report;
if not, such a report should be available at `http://localhost:9323`.

## Writing tests

Playwright uses its Locator system to select html elements. You can type your own,
but Playwright can help with that aswell. Inside a test, add `await window.pause()`
where required, then run said test. Doing so will open ivette, and,
when the instruction is reached, an additional Playwright window. On the bottom
of said window, there is a `Pick locator` button, which will provide the necessary
locator for the selected element (works similarly to the inspect functionality
of most browser developer tools).
The `locatorsUti.ts` files comes with several default locators.

Once the element selected, multiple operations can be realized.
Refer to the Playwright documentation for the complete list.
Examples are provided in `e2eService.ts`.

Complete tests scenarios are provided in `e2e.spec.ts`.

## Monkey Testing

From `ivette` directory, launch monkey testing (gremlins.js) with

`yarn playwright test monkey-testing.spec.ts`;

It is possible to seed a randomizer in order to obtain reproductible tests
(see the randomizer value in `monkey-testing.spec.ts`).

However for the test to be fully reproductible, Ivette also need to belaunch
with its default configuration. An additional argument `--init-settings` has
been added to Ivette for this purpose. User can provide a path to a settings
file with argument `--with-fixed-settings`, which will be used to
initialize Ivette's settings (the file is not modified when ivette exits).
An example on how to do so is available in `e2eService.ts`.
