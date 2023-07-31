import { test } from "@playwright/test";
import * as e2eService from "./libs/e2eService";

test('run gremlins.js', async () => {
    const launchAppResult = await e2eService.launchAppWithTestFileAndInitSettings();
    const electronApp = launchAppResult.app;
    const window = launchAppResult.page;

    // await window.pause()

    // Load gremlins.js script
    await window.addScriptTag({
        path: "./node_modules/gremlins.js/dist/gremlins.min.js",
    });

    // Launch gremlins.js with default settings
    // await window.evaluate(() => gremlins.createHorde().unleash());
    
    // Launch gremlins.js with custom settings
    // See https://github.com/marmelab/gremlins.js for more info
    
    await window.evaluate(async () => {
        await gremlins.createHorde({
            species: [
                gremlins.species.clicker(),     // clicks anywhere on the visible area of the document
                gremlins.species.toucher(),     // touches anywhere on the visible area of the document
                gremlins.species.scroller(),    // scrolls the viewport to reveal another part of the document
                gremlins.species.typer(),       // types keys on the keyboard
                gremlins.species.formFiller(),  // fills forms by entering data, selecting options, clicking checkboxes, etc
            ],
            mogwais: [
                gremlins.mogwais.alert(),       // prevents calls to alert() from blocking the test
                gremlins.mogwais.fps(),         // logs the number of frames per seconds (FPS) of the browser
                // gremlins.mogwais.gizmo()     // can stop the gremlins when they go too far
            ],
            strategies: [
                gremlins.strategies.distribution({
                    distribution: [0.3, 0.3, 0.3, 0.1, 0.1], // the first three gremlins have more chances to be executed than the last
                    delay: 10,                               // wait 10 ms between each action
                })
            ],
            randomizer: new gremlins.Chance(1234), // if you want the attack to be repeatable, you need to seed the random number generator
        }).unleash();
    });

    // Could be usefull if you want to review the logs
    // await window.pause()

    // Exit app.
    await electronApp.close();
});