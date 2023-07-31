import { Locator, Page } from "@playwright/test";


/**
 * Locator to select "Console" in the right menu
 */
export function getConsoleMenuItem(window: Page): Locator {
    return window.getByText('ViewsConsoleSource Code').getByText("Console").first();
}

/**
 * Locator to select the Start button in the top button bar
 */
export function getStartServerButton(window: Page): Locator {
    return window.locator(".dome-xToolBar").getByRole("button", { name: "Start the server" , exact: true});
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