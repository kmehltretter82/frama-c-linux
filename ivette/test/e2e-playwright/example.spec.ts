import { expect, test } from '@playwright/test';
import { _electron as electron } from 'playwright-core';

test('launch app', async () => {
    const electronApp = await electron.launch({ args: ['main.js', '--command', '/home/user01/artal/git/frama-c/bin/frama-c'] , cwd: "dist/main/"})

    // Evaluation expression in the Electron context.
    const appPath = await electronApp.evaluate(async ({ app }) => {
        // This runs in the main Electron process, parameter here is always
        // the result of the require('electron') in the main app script.
        return app.getAppPath();
    });
    console.log("appPath: ", appPath);

    // Get the first window that the app opens, wait if necessary.
    const window = await electronApp.firstWindow();

    // Click on the Console tab in the right menu.
    await window.getByText("Console").nth(1).click();

    // Await manual input by user to resume the test
    await window.pause()
    
    // Check the server status in the header's button bar
    await expect(window.locator(".dome-xToolBar").getByRole("button", { name: "Start the server" , exact: true})).toBeDisabled();
    // await expect(window.locator(".dome-xToolBar").getByRole("button", { name: "Start the server" , exact: true})).toBeEnabled(); -> Will Fail
    await expect(window.locator(".dome-xToolBar").getByTitle("Shut down the server")).toBeEnabled();

    // Check the server status in the console view
    await expect(window.locator(".CodeMirror").getByText('[server] Socket server running.')).toBeVisible();

    // Check the server status in the footer
    await expect(window.getByTitle("Server is running")).toHaveText("ON");
    
    // Capture a screenshot.
    await window.screenshot({ path: 'ivette.png' });


    // Exit app.
    await electronApp.close();
})