/* --------------------------------------------------------------------------*/
/* --- Lab View Component                                                 ---*/
/* --------------------------------------------------------------------------*/

/**
   @packageDocumentation
   @module ivette
 */

import React from 'react';
import { Label } from 'dome/controls/labels';
import { DefineElement } from 'dome/layout/dispatch';
import { GridItem, GridHbox, GridVbox } from 'dome/layout/grids';
import * as Lab from 'ivette@lab';
import * as Ext from 'ivette@ext';

/* --------------------------------------------------------------------------*/
/* --- Items                                                              ---*/
/* --------------------------------------------------------------------------*/

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

/* --------------------------------------------------------------------------*/
/* --- Groups                                                             ---*/
/* --------------------------------------------------------------------------*/

let GROUP: string | undefined;

/**
   Defines a group of components.
   To arrach components to the group, use their `group` property.
   Empty groups are not displayed.

   If provided, the group is used by default for all components registered
   during the continuation.
 */
export function registerGroup(group: ItemProps, job?: () => void) {
  Lab.addLibraryItem('groups', undefined, [], group);
  if (job) {
    const STACK = GROUP;
    try {
      GROUP = group.id;
      job();
    } finally {
      GROUP = STACK;
    }
  }
}

/* --------------------------------------------------------------------------*/
/* --- View Layout                                                        ---*/
/* --------------------------------------------------------------------------*/

/**
   Alternating V-split and H-split layouts.
 */
export type Layout = string | Layout[];

function makeLayout(ly: Layout, hsplit = false) {
  if (typeof (ly) === 'string') return <GridItem id={ly} />;
  if (!ly) return null;
  if (hsplit) {
    return (
      <GridHbox>
        {React.Children.toArray(ly.map((l) => makeLayout(l, false)))}
      </GridHbox>
    );
  }
  return (
    <GridVbox>
      {React.Children.toArray(ly.map((l) => makeLayout(l, true)))}
    </GridVbox>
  );

}

export interface ViewLayoutProps extends ItemProps {
  /** Use this view by default. */
  defaultView?: boolean;
  /** View layout. */
  layout: Layout;
}

/** Register a new View. */
export function registerView(view: ViewLayoutProps) {
  const { layout, ...viewprops } = view;
  Lab.addLibraryItem('views', undefined, [], {
    ...viewprops,
    children: makeLayout(layout),
  });
}

/* --------------------------------------------------------------------------*/
/* --- Components                                                         ---*/
/* --------------------------------------------------------------------------*/

export interface ComponentProps extends ContentProps {
  /** Group attachment. */
  group?: string;
}

/**
   Register the given Ivette Component.
   Components are sorted by rank and identifier among each group.
 */
export function registerComponent(props: ComponentProps) {
  Lab.addLibraryItem('components', GROUP, [], props);
}

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
export function TitleBar(props: TitleBarProps) {
  const { icon, label, title, children } = props;
  const context = Lab.useTitleContext();
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

/* --------------------------------------------------------------------------*/
/* --- Search Hints                                                       ---*/
/* --------------------------------------------------------------------------*/

export interface Hint {
  id: string;
  label: string | JSX.Element;
  title?: string;
  rank?: number;
  onSelection: () => void;
}

/**
   Register a hint search engine for the Ivette toolbar.
*/
export function registerHints(
  id: string,
  lookup: (pattern: string) => Promise<Hint[]>,
) {
  const adaptor = (h: Hint): Ext.SearchHint => (
    { ...h, value: () => h.onSelection() }
  );
  const search = (p: string) => lookup(p).then((hs) => hs.map(adaptor));
  Ext.registerHints({ id, search });
}

/* --------------------------------------------------------------------------*/
/* --- Sidebar Panels                                                     ---*/
/* --------------------------------------------------------------------------*/

export interface ToolProps {
  id: string;
  rank?: number;
  children?: React.ReactNode;
}

export function registerSidebar(panel: ToolProps) {
  Ext.SIDEBAR.register(panel);
}

export function registerToolbar(tools: ToolProps) {
  Ext.TOOLBAR.register(tools);
}

export function registerStatusbar(status: ToolProps) {
  Ext.STATUSBAR.register(status);
}

// --------------------------------------------------------------------------
