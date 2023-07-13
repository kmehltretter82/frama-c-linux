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
import { setupBrowser } from '@testing-library/webdriverio';

import { join } from 'path';
import { getDirname } from 'cross-dirname';

const dirname = getDirname();

const loadScript = (source, callback) => {
    let head = document.getElementsByTagName('head')[0];
    let scripts = head.getElementsByTagName('script');
    let found = false;
    for (var i = 0; i < scripts.length; i++) {
        if (scripts[i].src === source) {
            found = true;
            break;
        }
    }
    if (!found) {
        let script = document.createElement('script');
        script.type = 'text/javascript';
        if (script.readyState) {  //IE
            script.onreadystatechange = function () {
                if (script.readyState === 'loaded' ||
                    script.readyState === 'complete') {
                    script.onreadystatechange = null;
                    callback();
                }
            };
        } else {  //Others
            script.onload = callback;
        }
        script.src = source;
        head.appendChild(script);
    }
}

const unleashGremlins = (ttl, callback) => {
    const stop = () => {
        horde.stop();
        callback();
    }
    let horde = window.gremlins.createHorde({
        randomizer: new gremlins.Chance(4567)
    });
    setTimeout(stop, ttl);
    horde.unleash();
}


describe('monkey testing', () => {
    let screen;

    before(() => {
        console.log('dirname : ', dirname);
        screen = setupBrowser(browser);
    });

    describe('run gremlins.js', () => {
        it('it should not raise any error', async () => {
            const script_loc = join(dirname, '..', 'node_modules', 'gremlins.js', 'dist', 'gremlins.min.js');
            // Now load your gremlins
            await browser.executeAsync(loadScript, script_loc);
            // And unleash them
            await browser.executeAsync(unleashGremlins, 13000);
            // await browser.executeAsync(() => {let horde = window.gremlins.createHorde(); horde.unleash();});

            // await browser.debug();
        });
    });

});
