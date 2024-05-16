/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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
// --- Formatting Utilities
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/misc/format
 */

/**
   Formats a duration, specified in seconds, into hour, minutes, seconds,
   milliseconds or nanoseconds, depending on range.

   Negative or null durations are reported by `'0'`.

   For instance, returns `'250ms'` for an input time of `.25`.
 */
export function duration(time : number) : string {
  if (time <= 0.0) return '0';
  if (time < 1.0e-3) return `${Math.round(time * 1.0e6)}µs`;
  if (time < 1.0) return `${Math.round(time * 1.0e3)}ms`;
  if (time < 60) return `${Math.round(time)}s`;
  if (time < 3600) return `${Math.round(time / 60)}m`;
  const h = Math.round(time / 3600);
  const r = time - h * 3600;
  const m = Math.round(r / 60);
  return `${h}h ${m}m`;
}

// --------------------------------------------------------------------------
