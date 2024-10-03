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

/* -------------------------------------------------------------------------- */
/* --- Display Interaction                                                --- */
/* -------------------------------------------------------------------------- */

/**
   @packageDocumentation
   @module ivette/display
 */

import { LayoutPosition } from 'ivette';
import * as Laboratory from './laboratory';

/** Switch display to specified view. */
export function switchToView(id: string): void {
  Laboratory.switchToView(id);
}

/** Show component. */
export function showComponent(id: string, at?: LayoutPosition): void {
  Laboratory.showComponent(id, at);
}

/** Dock component. */
export function dockComponent(id: string, at?: LayoutPosition): void {
  Laboratory.dockComponent(id, at);
}

/** Alert component. */
export function alertComponent(id: string): void {
  Laboratory.alertComponent(id);
}

/** Component Status Hook. */
export function useComponentStatus(
  id: string | undefined
): Laboratory.ComponentStatus {
  const state = Laboratory.useState();
  return Laboratory.getComponentStatus(state, id ?? '');
}

export type Message = string | { label: string, title: string };

/** Message notification */
export function showMessage(msg: Message): void {
  if (!msg) return;
  const short = typeof msg === 'string';
  const label = short ? msg : msg.label;
  const title = short ? msg : msg.title;
  Laboratory.showMessage({ kind: "message", label, title });
}

/** Warning notification. */
export function showWarning(msg: Message): void {
  if (!msg) return;
  const short = typeof msg === 'string';
  const label = short ? msg : msg.label;
  const title = short ? msg : msg.title;
  Laboratory.showMessage({ kind: 'warning', label, title });
}

/** Error notification */
export function showError(msg: Message): void {
  if (!msg) return;
  const short = typeof msg === 'string';
  const label = short ? msg : msg.label;
  const title = short ? msg : msg.title;
  Laboratory.showMessage({ kind: 'error', label, title });
}

export function clearMessages(): void {
  Laboratory.clearMessages();
}

/* -------------------------------------------------------------------------- */
