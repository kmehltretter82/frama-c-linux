# How to execute e2e tests and monkey testing with Playwright

Official documentation:

- Playwright: <https://playwright.dev/>
- Gremlins.js: <https://github.com/marmelab/gremlins.js>

Playwright has native support for Electron applications. Examples on how to
launch Ivette with Frama-C's server are provided in `e2eService.ts` file, along
with an example loading a C file.

However:

- to have electron support (needed for Ivette), you need to build the `dist`
directory using `make dist` from the `ivette` directory then copy the entirety
of `dist/renderer` to `dist/main`
- if you want to connect to the Frama-C server, Frama-C needs to be built using
`make` from the `frama-c` directory.

In the provided tests, various path are provided within `e2eService.ts` to launch
Ivette with Frama-C or with additionnal C files. Those can be modified at will,
however it is recommanded to stick with relative paths for maintenability.

## Installation

If you're accessing this readme, if means that Playwright is already installed
for this project in `tests/e2e-playwright`.
The following instructions are provided if you wish to do a fresh install.

Playwright can be installed using Yarn (already done for ivette):

- `yarn create playwright` ;
  Be mindful of the different options asked by the installer:
- "Where to put your end-to-end tests" -> Directory that will create Playwright,
eg `tests/e2e-playwright`
- "Add a Github Actions worflow (y/N)" -> CI/CD feayures for GitHub. Not needed
since GitLab is used.
- "Install Playwright browsers (can be done manullay via 'yarn playwright install')?
(y/N)" -> Playwright will install it owns browsers for its tests instead of using
those installed. No needed since we use Electron instead of native browsers.
- "Install Playwright operating system dependencies (y/N)" -> Not needed

If you wish to run monkey testing, Gremlins.js also need to be installed
(already done for ivette):

- `yarn add gremlins.js`

## Launching tests

- From `ivette` directory,
launch a specific test with `yarn playwright test <file-name>`;
- From `ivette` directory,
launch e2e test with `yarn playwright test e2e.spec.ts`;
- From `ivette` directory,
launch monkey testing (gremlins.js) with `yarn playwright test monkey-testing.spec.ts`;
- From `ivette` directory,
launch ALL tests with `yarn playwright test` ;

## Accessing tests report

If the test fails, Playwright will automatically open its report.
To manually access the last report:

- From `ivette` directory, use `yarn playwright show-report`,
then access `localhost:9323` in a browser ;

Playwright options can me modified within its configuration file `playwright.config.ts`.
The `fullyParallel` option has been set to false, as this feature resulted
in concurency issues with Electron.

## Writing test files

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
been added to Ivette for this purpose.
An example on how to do so is available in `e2eService.ts`.
