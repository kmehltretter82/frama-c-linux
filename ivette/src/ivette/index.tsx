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

/* -------------------------------------------------------------------------- */
/* --- Lab View Component                                                 --- */
/* -------------------------------------------------------------------------- */

/**
   @packageDocumentation
   @module ivette
 */

import React from 'react';
import { DEVEL } from 'dome';
import { Label } from 'dome/controls/labels';
import { DefineElement } from 'dome/layout/dispatch';
import * as Ext from 'ivette@ext';

/* -------------------------------------------------------------------------- */
/* --- Items                                                              --- */
/* -------------------------------------------------------------------------- */

export interface ItemProps {
  /** Identifier. */
  id: string;
  /** Displayed name. */
  label: string;
  /** Tooltip description. */
  title?: string;
  /** Ordering index. */
  rank?: number;
}

export interface ContentProps extends ItemProps {
  /** Contents. */
  children?: React.ReactNode;
}

/* -------------------------------------------------------------------------- */
/* --- Groups                                                             --- */
/* -------------------------------------------------------------------------- */

/** @ignore */
export const GROUP = new Ext.ElementRack<ItemProps>();

/** Defines a group of components.

   The group with identifier `G` contains
   implicitely all components identified by pattern `G.*`. For instance,
   component `fc.kernel.ast` belongs to group `kernel`.

   Group `fc.kernel` is dedicated to components of the Kernel.
   Group `fc.<plugin>` is dedicated to components of plugin `<plugin>`.
   Groups `ivette` and `sandbox` are reserved for Ivette usage.

 */
export function registerGroup(group: ItemProps): void {
  GROUP.register(group);
}

/* -------------------------------------------------------------------------- */
/* --- View Layout                                                        --- */
/* -------------------------------------------------------------------------- */

/** Component identifier. */
export type compId = string;

/** Four elements layout */
export type Layout4 = { A: compId, B: compId, C: compId, D: compId };

/** Three elements layout: one component spreads over two quarters. */
export type Layout3 =
  | { AB: compId, C: compId, D: compId }
  | { AC: compId, B: compId, D: compId }
  | { A: compId, B: compId, CD: compId }
  | { A: compId, BD: compId, C: compId }

/** Two elements layout: each component spreads over two quarters. */
export type Layout2 =
  | { AB: compId, CD: compId }
  | { AC: compId, BD: compId }

/** One elements layout: a single component spreads over all quarters. */
export type Layout1 =
  | { ABCD: compId }

/** A layout displays one to four components. */
export type Layout = Layout1 | Layout2 | Layout3 | Layout4;

/** A view dispatches elements over a predefined layout. */
export interface ViewLayoutProps extends ItemProps {
  /** Use this view by default. */
  defaultView?: boolean;
  /** View layout. */
  layout: Layout;
}

/** @ignore */
export const VIEW = new Ext.ElementRack<ViewLayoutProps>();

/** Register a new View. */
export function registerView(view: ViewLayoutProps): void {
  VIEW.register(view);
}

/* -------------------------------------------------------------------------- */
/* --- Components                                                         --- */
/* -------------------------------------------------------------------------- */

export type LayoutPosition =
  | 'A' | 'B' | 'C' | 'D'
  | 'AB' | 'AC' | 'BD' | 'CD'
  | 'ABCD';

export interface ComponentProps extends ContentProps {
  /** Defaults to 'D' */
  preferredPosition?: LayoutPosition;
}

/** @ignore */
export const COMPONENT = new Ext.ElementRack<ComponentProps>();

/**
   Register the given Ivette Component.
   Components are sorted by rank and identifier among each group.
 */
export function registerComponent(props: ComponentProps): void {
  COMPONENT.register(props);
}

/* -------------------------------------------------------------------------- */
/* --- TitleBar Component                                                 --- */
/* -------------------------------------------------------------------------- */

/** @ignore */
export interface TitleContext {
  id?: string;
  label?: string;
  title?: string;
}

/** @ignore */
export const TitleContext = React.createContext<TitleContext>({});

export interface TitleBarProps {
  /** Displayed icon. */
  icon?: string;
  /** Displayed name (when mounted). */
  label?: string;
  /** Tooltip description (when mounted). */
  title?: string;
  /** TitleBar additional components (stacked to right). */
  children?: React.ReactNode;
}

/**
   LabView Component's title bar.
   Defines an alternative component title bar in current context.
   Default values are taken from the associated component.
 */
export function TitleBar(props: TitleBarProps): JSX.Element | null {
  const { icon, label, title, children } = props;
  const context = React.useContext(TitleContext);
  if (!context.id) return null;
  return (
    <DefineElement id={`labview.title.${context.id}`}>
      <Label
        className="labview-handle"
        icon={icon}
        label={label || context.label}
        title={title || context.title}
      />
      {children}
    </DefineElement>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Sidebar Panels                                                     --- */
/* -------------------------------------------------------------------------- */

export interface ToolProps {
  id: string;
  rank?: number;
  children?: React.ReactNode;
}

/** @ignore */
export const TOOLBAR = new Ext.ElementRack<ToolProps>();

/** @ignore */
export const STATUSBAR = new Ext.ElementRack<ToolProps>();

export function registerToolbar(tools: ToolProps): void {
  TOOLBAR.register(tools);
}

export function registerStatusbar(status: ToolProps): void {
  STATUSBAR.register(status);
}

/* -------------------------------------------------------------------------- */
/* --- Sidebar                                                           ---  */
/* -------------------------------------------------------------------------- */

export interface SidebarProps extends ContentProps {
  iconPath?: string;
}

/** @ignore */
export const SIDEBAR = new Ext.ElementRack<SidebarProps>();

export function registerSidebar(sidebar: SidebarProps): void {
  SIDEBAR.register(sidebar);
}

/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */

if (DEVEL) {
  registerGroup({
    id: 'sandbox',
    label: 'Sandbox',
    title: 'Ivette Sandbox Components (only in DEVEL mode)',
  });
  registerView({
    id: 'sandbox',
    label: 'Sandbox',
    title: 'Sandbox Playground (only in DEVEL mode)',
    layout: { ABCD: 'sandbox.qsplitter' },
  });
}

export function registerSandbox(props: ComponentProps): void {
  if (DEVEL) {
    if (!props.id.startsWith('sandbox.')) {
      // eslint-disable-next-line no-console
      console.error('SANDBOX wrong identifier', props.id);
    }
    registerComponent(props);
  }
}

/* -------------------------------------------------------------------------- */
