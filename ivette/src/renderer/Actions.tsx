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

// --------------------------------------------------------------------------
// --- Extensible Search Field
// --------------------------------------------------------------------------

import React from 'react';
import * as Dome from 'dome';
import * as Toolbar from 'dome/frame/toolbars';
import { GlobalState, useGlobalState } from 'dome/data/states';

// --------------------------------------------------------------------------
// --- Search Actions Registry
// --------------------------------------------------------------------------

export interface Hint {
  id: string | number;
  name?: string;
  icon?: string;
  label?: string;
  title?: string;
  rank?: number;
  onClick?: () => void;
}

export interface ModeProps {
  id: string;
  icon?: string;
  label?: string;
  title?: string;
  placeholder?: string;
  className?: string;
  enabled?: boolean;
  hints?: () => Hint[];
  onHint?: (hint: Hint) => void;
  onEnter?: (pattern: string) => void;
}

const defaultMode : ModeProps = { id: '' };

class ModeManager extends GlobalState<ModeProps[]> {
  constructor() { super([]); }
  private registry: Map<string, ModeProps> = new Map();
  private emit(): void {
    this.setValue(Array.from(this.registry, ([_, v]) => v));
  }

  find(id: string): ModeProps | undefined {
    return this.registry.get(id);
  }

  register(m: ModeProps): void {
    this.registry.set(m.id, m);
    this.emit();
  }

  update(m: ModeProps): void {
    const { id, ...data } = m;
    const mprops = this.registry.get(id) ?? {};
    this.registry.set(m.id, { ...mprops, ...data, id });
    this.emit();
  }

  remove(id: string): void {
    this.registry.delete(id);
    this.emit();
  }
}

const allModes = new ModeManager();
const currentMode = new GlobalState<ModeProps>(defaultMode);
const focus = new Dome.Event<void>('ivette.search.focus');

// --------------------------------------------------------------------------
// --- Ivette Extension Points
// --------------------------------------------------------------------------

export function registerMode(m: ModeProps): void { allModes.register(m); }
export function updateMode(m: ModeProps): void { allModes.update(m); }
export function removeMode(id: string): void { allModes.remove(id); }

export function findMode(id: string): ModeProps | undefined {
  return allModes.find(id);
}

export function focusMode(id: string): void {
  const m = allModes.find(id);
  if (m !== undefined) {
    currentMode.setValue(m);
    focus.emit();
  }
}

// --------------------------------------------------------------------------
// --- Search Action Component
// --------------------------------------------------------------------------

function lookupHint(h: Hint, lp: string): boolean {
  const hn = h.name ?? h.label;
  return hn ? hn.toLowerCase().includes(lp) : false;
}

function toHint(h: Hint): Toolbar.Hint
{
  const label = h.label ?? h.name ?? String(h.id);
  return { ...h, label };
}

function lookupHints(hs: Hint[], pattern: string): Toolbar.Hint[]
{
  const p = pattern.toLowerCase();
  return hs.filter((h) => lookupHint(h, p)).map(toHint);
}

export function SearchAction(): JSX.Element {
  const [mode] = useGlobalState(currentMode);
  const [pattern, onPattern] = React.useState('');
  const { hints: getHints } = mode;
  const hints = React.useMemo(() => {
    if (!getHints) return [];
    return lookupHints(getHints(), pattern);
  }, [getHints, pattern]);
  return (
    <Toolbar.SearchField
      icon={mode.icon}
      title={mode.title}
      placeholder={mode.placeholder}
      hints={hints}
      onHint={mode.onHint}
      onEnter={mode.onEnter}
      onPattern={onPattern}
      enabled={mode.id !== ''}
      focus={focus}
    />
  );
}

// --------------------------------------------------------------------------
