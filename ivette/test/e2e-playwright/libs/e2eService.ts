import { ElectronApplication, Page, expect } from '@playwright/test';
import { _electron as electron } from 'playwright-core';
import * as locs from "./locatorsUtil";

/**
 * Basic Electron launch of Ivette for Playwright e2e tests
 */
export async function launchApp(): Promise<{ app: ElectronApplication, page: Page }> {
    try {

        const electronApp = await electron.launch({
            env: {
                ...process.env,
                NODE_ENV: "development",
            },
            args: [
                'main.js',
                '--command',
                '/builds/frama-c/frama-c/bin/frama-c',
            ],
            cwd: "dist/main/",
        });

        // Get the first window that the app opens, wait if necessary.
        const window = await electronApp.firstWindow();

        return {
            app: electronApp,
            page: window
        }
    } catch (error) {
        console.log("------> Error: ", error);
        throw error;
    }
}

/**
 * Electron launch of Ivette for Playwright e2e tests using Ivette's default settings
 */
export async function launchAppInitSettings(): Promise<{ app: ElectronApplication, page: Page }> {
    try {
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
                "--init-settings"
            ],
            cwd: "dist/main/",
        });

        const window = await electronApp.firstWindow();

        return {
            app: electronApp,
            page: window
        }
    }
    catch (error) {
        console.log("------> Error: ", error);
        throw error;
    }
}

/**
 * Electron launch of Ivette for Playwright e2e tests using an additional C file loaded
 */
export async function launchAppWithTestFile(): Promise<{ app: ElectronApplication, page: Page }> {
    try {
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
                "/builds/frama-c/frama-c/tests/test/adpcm.c"
            ],
            cwd: "dist/main/",
        });

        // Get the first window that the app opens, wait if necessary.
        const window = await electronApp.firstWindow();

        return {
            app: electronApp,
            page: window
        }
    } catch (error) {
        console.log("------> Error: ", error);
        throw error;
    }
}

/**
 * Electron launch of Ivette for Playwright e2e tests using an additional C file loaded
 */
export async function launchAppWithTestFileAndInitSettings(): Promise<{ app: ElectronApplication, page: Page }> {
    try {
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
                '--init-settings',
                "/builds/frama-c/frama-c/tests/test/adpcm.c"
            ],
            cwd: "dist/main/",
        });

        // Get the first window that the app opens, wait if necessary.
        const window = await electronApp.firstWindow();

        return {
            app: electronApp,
            page: window
        }
    } catch (error) {
        console.log("------> Error: ", error);
        throw error;
    }
}

export async function testServerIsStarted(window: Page) {
    // Click on the Console tab in the right menu.
    await locs.getConsoleMenuItem(window).click();

    // Check the server status in the header's button bar
    await expect(locs.getStartServerButton(window)).toBeDisabled();
    await expect(locs.getShutDownServerButton(window)).toBeEnabled();
    // -> Will Fail if the server is started
    // await expect(locs.getStartServerButton(window)).toBeEnabled();    

    // Check the server status in the console view
    await expect(locs.getConsoleView(window).getByText('[server] Socket server running.')).toBeVisible();

    // Check the server status in the footer
    await expect(locs.getServerStatusLabel(window)).toHaveText("ON");
}

export async function testFileIsLoaded(window: Page) {

    // check if a message is present in the console view to confirm the file loaded
    await expect(locs.getConsoleView(window).getByText('adpcm.c (with preprocessing)')).toBeVisible();

    // check if the main function is visible in the functions view
    await expect(locs.getFunctionsSideBar(window).getByText('main', { exact: true })).toBeVisible();
}