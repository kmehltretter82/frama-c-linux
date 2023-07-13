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

import { browser } from 'wdio-electron-service';
import { setupBrowser, WebdriverIOQueries } from '@testing-library/webdriverio';

// import { execFileSync, execSync } from 'child_process';

import {v4 as uuidv4} from 'uuid';


// import { join } from 'path';
// import { getDirname } from 'cross-dirname';

// const dirname = getDirname();

describe('application loading', () => {
    let screen: WebdriverIOQueries;

    before(() => {
        console.log("before in spec");
        //execFileSync(join(dirname, '..', 'scripts', 'before.sh'));
        console.log(`OPAM_SWITCH_PREFIX value is: ${process.env.OPAM_SWITCH_PREFIX}`);
        console.log(`CAML_LD_LIBRARY_PATH value is: ${process.env.CAML_LD_LIBRARY_PATH}`);
        console.log(`OCAML_TOPLEVEL_PATH value is: ${process.env.OCAML_TOPLEVEL_PATH}`);
        console.log(`PKG_CONFIG_PATH value is: ${process.env.PKG_CONFIG_PATH}`);
        console.log(`MANPATH value is: ${process.env.MANPATH}`);
        console.log(`PATH value is: ${process.env.PATH}`);
        screen = setupBrowser(browser);
    });

    // Cover a few WebdriverIO expect matchers -  https://webdriver.io/docs/api/expect-webdriverio

/*     describe('DOM', () => {
        it('on cherche le button de decrease', async () => {
            await expect(await screen.getByTitle('Decrease font size')).toExist();
        });
        it('on cherche le button de increase', async () => {
            await expect(await screen.getByTitle('Increase font size')).toExist();
        });
        it('on cherche le button show/hide side bar', async () => {
            await expect(await screen.getByTitle('Show/Hide side bar')).toExist();
        });
        it('on cherche le button start the server', async () => {
            await expect(await screen.getByTitle('Start the server')).toExist();
        });        
        it('on cherche la side bar', async () => {
            await expect(await browser.$('.sidebar-ruler')).toExist();
        });
        it('le container de la sidebar est visible', async () => {
            await expect(await browser.$('.dome-xSplitter-hfold.dome-container')).toExist();
        });
        it('pas de container de la sidebar qui soit invisible', async () => {
            await expect(await browser.$('.dome-xSplitter-hidden.dome-container')).not.toExist();
        });
    }); */

    describe('when the show/hide side bar button is clicked', () => {
        it('hide side bar', async () => {

            // execSync(join(dirname, '..', 'scripts', 'before.sh'));
            // screen = setupBrowser(browser);
            const elem = await screen.getByTitle('Show/Hide side bar');

            // Click pour masquer sidebar
            await elem.click();
            it('container de la sidebar est invisible', async () => {
                await expect(await browser.$('.dome-xSplitter-hfold .dome-container')).not.toExist();
                await expect(await browser.$('.dome-xSplitter-hidden .dome-container')).toExist();
            });

            await browser.pause(1000);

            // Reclick pour rafficher sidebar
            await elem.click();
            it('container de la sidebar visible', async () => {
                await expect(await browser.$('.dome-xSplitter-hfold .dome-container')).toExist();
                await expect(await browser.$('.dome-xSplitter-hidden .dome-container')).not.toExist();
            });

            await browser.pause(1000);

            // reClick pour masquer sidebar
            await elem.click();
            it('container de la sidebar est invisible', async () => {
                await expect(await browser.$('.dome-xSplitter-hfold .dome-container')).not.toExist();
                await expect(await browser.$('.dome-xSplitter-hidden .dome-container')).toExist();
            });

            await browser.pause(1000);

            // Reclick pour rafficher sidebar
            await elem.click();
            it('container de la sidebar visible', async () => {
                await expect(await browser.$('.dome-xSplitter-hfold .dome-container')).toExist();
                await expect(await browser.$('.dome-xSplitter-hidden .dome-container')).not.toExist();
            });

            await browser.pause(1000);

            // await browser.debug();

            let myuuid = uuidv4();
            await browser.saveScreenshot('/home/user01/Documents/sources/frama-c/screenshots/' + myuuid + '.png');

        });
    });

/*     describe('when the start the server button is clicked', () => {
        it('start the server', async () => {
            const elem = await screen.getByTitle('Start the server');
            await elem.click();
            await browser.pause(3000);
        });
    });   */  
});
