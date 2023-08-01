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
import { _electron as electron } from "playwright-core";

test("launch app", async () => {
  const electronApp = await electron.launch({
    env: {
      ...process.env,
      NODE_ENV: "development",
    },
    args: [
      "main.js",
      "--enable-logging",
      "--no-sandbox",
      "--command",
      "/builds/frama-c/frama-c/bin/frama-c",
    ],
    cwd: "dist/main/",
  });

  // Evaluation expression in the Electron context.
  const appPath = await electronApp.evaluate(async ({ app }) => {
    // This runs in the main Electron process, parameter here is always
    // the result of the require('electron') in the main app script.
    return app.getAppPath();
  });
  console.log("appPath: ", appPath);

  // // Get the first window that the app opens, wait if necessary.
  const window = await electronApp.firstWindow();

  await window.screenshot({ path: "screenshots/start.png" });
  console.log("Screenshot taken");

  // Click on the Console tab in the right menu.
  await window.getByText("Console").nth(1).click();
  console.log("Console tab clicked");

  await window.screenshot({ path: "screenshots/console.png" });

  // Capture a screenshot.
  await window.screenshot({ path: "screenshots/end.png" });
  console.log("Done");

  // Exit app.
  await electronApp.close();

});
