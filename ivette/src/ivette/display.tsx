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

import React from 'react';
import { VIEW, COMPONENT, LayoutPosition } from 'ivette';
import * as State from './state';
import * as Laboratory from './laboratory';

export interface ItemProps {
  id: string;
  selected?: boolean;
}

/**
   A sidebar item for controlling an Ivette view.
 */
export function ViemItem(props: ItemProps): JSX.Element | null {
  const { id, selected = false } = props;
  const view = State.useElement(VIEW, id);
  const state = Laboratory.useState();
  if (!view) return null;
  const status = Laboratory.getViewStatus(state, id);
  return (
    <Laboratory.ViewItem
      view={view}
      selected={selected}
      {...status}
    />
  );
}

/**
   A sidebar item for controlling an Ivette component.
 */
export function ComponentItem(props: ItemProps): JSX.Element | null {
  const { id, selected = false } = props;
  const comp = State.useElement(COMPONENT, id);
  const state = Laboratory.useState();
  if (!comp) return null;
  const status = Laboratory.getComponentStatus(state, id);
  return (
    <Laboratory.ComponentItem
      comp={comp}
      selected={selected}
      {...status}
    />
  );
}

export interface GroupItemsProps {
  id: string;
  selected?: string;
}

/**
   A bundle of sidebar items for controlling an Ivette group of components.
 */
export function GroupItems(props: GroupItemsProps): JSX.Element | null {
  const items =
    State.useElements(COMPONENT)
      .filter(Laboratory.inGroup(props))
      .map(({ id }) => (
        <ComponentItem
          key={id}
          id={id}
          selected={id === props.selected} />
      ));
  return <>{items}</>;
}

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
