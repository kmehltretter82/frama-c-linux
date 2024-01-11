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

import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import react from "@vitejs/plugin-react";
import path from "path"

const DOME = process.env.DOME || path.resolve("src", "dome");
const ENV = process.env.DOME_ENV;

// Do not use electron-devtools-installer in production mode
function domeDevtools() {
  switch (ENV) {
    case "dev":
      return "electron-devtools-installer";
    default:
      return path.resolve(DOME, "misc/devtools.js");
  }
}

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      extensions: ['.ts', '.tsx', '.js', 'jsx', '.json'],
      alias: {
        'frama-c/api': path.resolve(__dirname, 'src/frama-c/api/generated'),
        'frama-c': path.resolve(__dirname, 'src/frama-c'),
        'ivette@ext': path.resolve(__dirname, 'src/renderer/Extensions'),
        'ivette@lab': path.resolve(__dirname, 'src/renderer/Laboratory'),
        'ivette@mode': path.resolve(__dirname, 'src/renderer/Actions'),
        'ivette': path.resolve(__dirname, 'src/ivette'),
        'dome/misc': path.resolve(DOME, 'misc'),
        'dome/system': path.resolve(DOME, 'misc', 'system.ts'),
        'dome$': path.resolve(DOME, 'main', 'dome.ts'),
        'dome': path.resolve(DOME, 'renderer'),
      },
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
  },
  renderer: {
    resolve: {
      extensions: ['.ts', '.tsx', '.js', 'jsx', '.json'],
      alias: {
        'frama-c/api': path.resolve(__dirname, 'src/frama-c/api/generated'),
        'frama-c': path.resolve(__dirname, 'src/frama-c'),
        'ivette@ext': path.resolve(__dirname, 'src/renderer/Extensions'),
        'ivette@lab': path.resolve(__dirname, 'src/renderer/Laboratory'),
        'ivette@mode': path.resolve(__dirname, 'src/renderer/Actions'),
        'ivette': path.resolve(__dirname, 'src/ivette'),
        'dome/misc': path.resolve(DOME, 'misc'),
        'dome/system': path.resolve(DOME, 'misc', 'system.ts'),
        'dome$': path.resolve(DOME, 'main', 'dome.ts'),
        'dome': path.resolve(DOME, 'renderer'),
        // dome: path.resolve(DOME, 'renderer'),
        // 'dome$': path.resolve(DOME, 'main/dome.ts'),
        // 'frama-c': path.resolve('src/frama-c'),
        // 'ivette@ext': path.resolve('src/renderer/Extensions'),
        // 'ivette@lab': path.resolve('src/renderer/Laboratory'),
        // 'ivette@mode': path.resolve('src/renderer/Actions'),
        // ivette: path.resolve('src/ivette'),
        // // "dome/misc": path.resolve(DOME, "misc"),
        // // "@renderer": resolve("src/renderer"),
        // 'ivette/prefs': path.resolve('src', 'ivette', 'prefs'),
        // 'devtools': path.resolve(DOME, 'misc', 'devtools.js'),
        // system: path.resolve(DOME, 'misc/system.ts'),
        // utils: path.resolve(DOME, 'misc/utils'),
        // 'dome/layout/boxes': path.resolve(DOME, 'renderer', 'layout', 'boxes'),
        // 'dome/layout/splitters': path.resolve(
        //   DOME,
        //   'renderer',
        //   'layout',
        //   'splitters'
        // ),
      },
    },
    plugins: [react()],
  },
});
