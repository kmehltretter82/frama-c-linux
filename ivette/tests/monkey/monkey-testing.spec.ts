/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
/*     CEA (Commissariat à l'énergie atomique et aux énergies               */
/*          alternatives)                                                   */
/*                                                                          */
/*   you can redistribute it and/or modify it under the terms of the GNU    */
/*   Lesser General Public License as published by the Free Software        */
/*   Foundation, version 2.1.                                               */
/*                                                                          */
/*   It is distributed in the hope that it will be useful,                  */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          */
/*   GNU Lesser General Public License for more details.                    */
/*                                                                          */
/*   See the GNU Lesser General Public License version 2.1                  */
/*   for more details (enclosed in the file licenses/LGPLv2.1).             */
/*                                                                          */
/* ************************************************************************ */

import { test } from "@playwright/test";
import * as e2eService from "../libs/e2eService";

/* eslint-disable  @typescript-eslint/no-explicit-any */
let gremlins: any;

test("run gremlins.js", async () => {
  const launchAppResult = await e2eService.launchApp(
    e2eService.argsLaunchWithTestFile,
  );
  const electronApp = launchAppResult.app;
  const window = launchAppResult.page;

  // await window.pause()

  // Load gremlins.js script
  await window.addScriptTag(
    { path: "./node_modules/gremlins.js/dist/gremlins.min.js", }
  );

  // Launch gremlins.js with default settings
  // await window.evaluate(() => gremlins.createHorde().unleash());

  // Launch gremlins.js with custom settings
  // See https://github.com/marmelab/gremlins.js for more info

  await window.evaluate(async () => {
    await gremlins
      .createHorde({
        species: [
          gremlins.species.clicker(), // clicks anywhere on the visible area of the document
          gremlins.species.toucher(), // touches anywhere on the visible area of the document
          gremlins.species.scroller(), // scrolls the viewport to reveal another part of the document
          gremlins.species.typer(), // types keys on the keyboard
          gremlins.species.formFiller(), // fills forms by entering data, selecting options, clicking checkboxes, etc
        ],
        mogwais: [
          gremlins.mogwais.alert(), // prevents calls to alert() from blocking the test
          gremlins.mogwais.fps(), // logs the number of frames per seconds (FPS) of the browser
        ],
        strategies: [
          gremlins.strategies.distribution({
            distribution: [0.3, 0.3, 0.3, 0.1, 0.1], // the first three gremlins have more chances to be executed than the last
            delay: 10, // wait 10 ms between each action
          }),
        ],
        randomizer: new gremlins.Chance(1234), // if you want the attack to be repeatable, you need to seed the random number generator
      })
      .unleash();
  });

  // Could be useful if you want to review the logs
  // await window.pause()

  // Exit app.
  await electronApp.close();
});
