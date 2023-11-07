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

import { Locator, Page } from "@playwright/test";

/**
 * Locator to select "Console" in the right menu
 */
export function getConsoleMenuItem(window: Page): Locator {
  return window
    .getByText("ViewsConsoleSource Code")
    .getByText("Console")
    .first();
}

/**
 * Locator to select the Start button in the top button bar
 */
export function getStartServerButton(window: Page): Locator {
  return window
    .locator(".dome-xToolBar")
    .getByRole("button", { name: "Start the server", exact: true });
}

/**
 * Locator to select the Shut Down button in the top button bar
 */
export function getShutDownServerButton(window: Page): Locator {
  return window.locator(".dome-xToolBar").getByTitle("Shut down the server");
}

/**
 * Locator to select the Console View
 */
export function getConsoleView(window: Page): Locator {
  return window.locator(".CodeMirror");
}

/**
 * Locator to select the Functions side bar when loading a file
 */
export function getFunctionsSideBar(window: Page): Locator {
  return window.locator(".dome-xSideBar").first();
}

export function getServerStatusLabel(window: Page): Locator {
  return window.getByTitle("Server is running");
}

/**
 * Locator to access the primary section (categories) of the double bar
 */
export function getDoubleBarPrimary(window: Page): Locator {
  return window.locator('.dome-xDoubleBar-primary');
}

/**
 * Locator to access the secondary section (submenu) of the double bar
 */
export function getDoubleBarSecondary(window: Page): Locator {
  return window.locator('dome-xSideBar-double-secondary');
}
