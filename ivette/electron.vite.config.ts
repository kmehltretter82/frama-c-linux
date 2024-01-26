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
import path from "path";

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
      extensions: [".ts", ".tsx", ".js", "jsx", ".json"],
      alias: {
        "dome/misc/devtools": domeDevtools(),
        "dome/misc": path.resolve(DOME, "misc"),
        "dome/system": path.resolve(DOME, "misc", "system.ts"),
        "dome$": path.resolve(DOME, "main", "dome.ts"),

      },
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
  },
  renderer: {
    resolve: {
      extensions: [".ts", ".tsx", ".js", "jsx", ".json"],
      alias: {
        "frama-c/api": path.resolve(__dirname, "src", "frama-c", "api", "generated"),
        "frama-c": path.resolve(__dirname, "src", "frama-c"),
        "ivette@ext": path.resolve(__dirname, "src", "renderer", "Extensions"),
        "ivette@lab": path.resolve(__dirname, "src", "renderer", "Laboratory"),
        "ivette@mode": path.resolve(__dirname, "src", "renderer", "Actions"),
        "ivette": path.resolve(__dirname, "src", "ivette"),
        "dome/misc": path.resolve(DOME, "misc"),
        "dome/system": path.resolve(DOME, "misc", "system.ts"),
        "dome/layout": path.resolve(DOME, "renderer", "layout"),
        "dome/frame": path.resolve(DOME, "renderer", "frame"),
        "dome/errors": path.resolve(DOME, "renderer", "errors"),
        "dome/data": path.resolve(DOME, "renderer", "data"),
        "dome/text": path.resolve(DOME, "renderer", "text"),
        "dome/controls": path.resolve(DOME, "renderer", "controls"),
        "dome/dialogs": path.resolve(DOME, "renderer", "dialogs"),
        "dome/olddnd": path.resolve(DOME, "renderer", "olddnd"),
        "dome/dnd": path.resolve(DOME, "renderer", "dnd"),
        "dome/themes": path.resolve(DOME, "renderer", "themes"),
        "dome/table": path.resolve(DOME, "renderer", "table"),
        "dome": path.resolve(DOME, "renderer", "dome.tsx"),
      },
    },
    plugins: [react()],
  },
});
