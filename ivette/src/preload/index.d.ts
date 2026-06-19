/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

export { };
import { ElectronAPI } from '@electron-toolkit/preload';

interface ElectronAPIWithArgv extends ElectronAPI {
  argv: string[];
}

declare global {
  interface Window {
    electron: ElectronAPIWithArgv;
  }
}
