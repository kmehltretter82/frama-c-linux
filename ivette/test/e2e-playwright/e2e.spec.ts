import { test } from '@playwright/test';
import * as e2eService from "./libs/e2eService";

test('launch app', async () => {
    const launchAppResult = await e2eService.launchApp();
    const electronApp = launchAppResult.app;
    const window = launchAppResult.page;

    await window.waitForTimeout(1000);

    // Exit app.
    await electronApp.close();
});


test('check server connection', async () => {
    const launchAppResult = await e2eService.launchApp();
    const electronApp = launchAppResult.app;
    const window = launchAppResult.page;

    // Await manual input by user to resume the test
    // await window.pause();

    await e2eService.testServerIsStarted(window);
    
    // Capture a screenshot.
    await window.screenshot({ path: 'test/screenshots/e2e-server-status.png' });

    // Exit app.
    await electronApp.close();
});

test('launch app with file', async () => {    
    const launchAppResult = await e2eService.launchAppWithTestFile();
    const electronApp = launchAppResult.app;
    const window = launchAppResult.page;

    await window.waitForTimeout(1000);

    await window.screenshot({ path: 'test/screenshots/e2e-file-load.png' });

    await e2eService.testFileIsLoaded(window);

    // Exit app.
    await electronApp.close();
});