/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

// --------------------------------------------------------------------------
// --- Frama-C Utilities
// --------------------------------------------------------------------------

/**
 * @packageDocumentation
 * @module frama-c/utils
*/

import * as Dome from 'dome';
import * as DomeBuffers from 'dome/text/buffers';
import * as KernelData from 'frama-c/api/kernel/data';

const D = new Dome.Debug('Utils');

// --------------------------------------------------------------------------
// --- Print Utilities
// --------------------------------------------------------------------------

/**
 * Print text containing tags into buffer.
 * @param buffer Rich text buffer to print into.
 * @param contents Actual text containing tags.
 * @param options Specify particular marker options.
 */
export function printTextWithTags(
  buffer: DomeBuffers.RichTextBuffer,
  contents: KernelData.text,
  options?: DomeBuffers.MarkerProps,
) {
  if (Array.isArray(contents)) {
    let marker = false;
    const tag = contents.shift();
    if (tag) {
      if (Array.isArray(tag)) {
        contents.unshift(tag);
      } else {
        buffer.openTextMarker({ id: tag, ...options ?? {} });
        marker = true;
      }
    }
    contents.forEach((txt) => printTextWithTags(buffer, txt, options));
    if (marker) {
      marker = false;
      buffer.closeTextMarker();
    }
  } else if (typeof contents === 'string') {
    buffer.append(contents);
  } else {
    D.error('Unexpected text', contents);
  }
}
