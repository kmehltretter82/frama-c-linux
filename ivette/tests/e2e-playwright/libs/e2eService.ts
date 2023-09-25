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

import { ElectronApplication, Page, expect } from "@playwright/test";
import { _electron as electron } from "playwright-core";
import * as locs from "./locatorsUtil";

// Basic Electron launch of Ivette for Playwright e2e tests
export const argsDefaultLaunch: string[] = [
  "./dist/main/main.js",
  "--no-sandbox",
  "--command",
  "../bin/frama-c",
];

// Electron launch of Ivette for Playwright
// e2e tests using Ivette's default settings
export const argsLaunchWithDefaultSettings: string[] = [
  "./dist/main/main.js",
  "--no-sandbox",
  "--init-settings",
  "--command",
  "../bin/frama-c",
];

// Electron launch of Ivette for Playwright
// e2e tests using an additional C file loaded
export const argsLaunchWithTestFile: string[] = [
  "./dist/main/main.js",
  "--no-sandbox",
  "--command",
  "../bin/frama-c",
  "../tests/test/adpcm.c",
];
/**
 * Basic Electron launch of Ivette for Playwright e2e tests
 */
export async function launchApp(
  params: string[]
): Promise<{ app: ElectronApplication; page: Page }> {
  const electronApp = await electron.launch({
    env: {
      ...process.env,
      NODE_ENV: "development",
    },
    args: params,
  });

  // Get the first window that the app opens, wait if necessary.
  const window = await electronApp.firstWindow();

  return {
    app: electronApp,
    page: window,
  };
}

export async function testServerIsStarted(window: Page): Promise<void> {
  // Click on the Console tab in the right menu.
  await locs.getConsoleMenuItem(window).click();

  window.waitForTimeout(5000);
  window.screenshot({ path: `./screenshots/${Date.now()}-console.png` });

  // Check the server status in the header's button bar
  await expect(locs.getStartServerButton(window)).toBeDisabled();
  await expect(locs.getShutDownServerButton(window)).toBeEnabled();
  // -> Will Fail if the server is started
  // await expect(locs.getStartServerButton(window)).toBeEnabled();

  // Check the server status in the console view
  await expect(
    locs.getConsoleView(window).getByText("[server] Socket server running.")
  ).toBeVisible();

  // Check the server status in the footer
  await expect(locs.getServerStatusLabel(window)).toHaveText("ON");
}

export async function testFileIsLoaded(window: Page): Promise<void> {
  await locs.getConsoleMenuItem(window).click();
  // check if a message is present in the console view
  // to confirm the file loaded
  await expect(
    locs.getConsoleView(window).getByText("adpcm.c (with preprocessing)")
  ).toBeVisible();

  // check if the main function is visible in the functions view
  await expect(
    locs.getFunctionsSideBar(window).getByText("main", { exact: true })
  ).toBeVisible();
}
