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
/* --- Fragments                                                          ---*/
/* --------------------------------------------------------------------------*/

export interface FragmentProps {
  group?: string;
  rank?: number;
  children?: React.ReactNode;
}

/**
   Ordered collection of LabView Components.
   Otherwise, elements are ordered by `rank` and `id`.
   @deprecated Use [[registerComponent]] with `rank` property.
 */
export function Fragment(props: FragmentProps) {
  const { group, rank, children } = props;
  const context = Lab.useGroupContext();
  const base = context.order ?? [];
  return (
    <Lab.Rankify
      group={group ?? context.group}
      order={rank === undefined ? base : [...base, rank]}
    >
      {children}
    </Lab.Rankify>
  );
}

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
}

export interface ContentProps extends ItemProps {
  /** Contents. */
  children?: React.ReactNode;
}

/* --------------------------------------------------------------------------*/
/* --- Groups                                                             ---*/
/* --------------------------------------------------------------------------*/

/**
   Defines a group of components.
   To arrach components to the group, use their `group` property.
   Empty groups are not displayed.
 */
export function registerGroup(group: ItemProps) {
  Lab.addLibraryItem('groups', group);
}

/**
   Defines a group of components. The components rendered
   _inside_ its content are implicitely affected to this group,
   unless specified. The group content are also rendered
   in their specified order. For nested collections of components,
   use `<Fragment/>` instead of `<React.Fragment/>` to specify order.
   @deprecated Use [[registerGroup]] instead.
 */
export function Group(props: ContentProps) {
  const { children, ...group } = props;
  const context = Lab.useLibraryItem('groups', group);
  return (
    <Lab.Rankify
      group={props.id}
      order={context.order ?? []}
    >
      {children}
    </Lab.Rankify>
  );
}

/* --------------------------------------------------------------------------*/
/* --- View Layout                                                        ---*/
/* --------------------------------------------------------------------------*/

export type Layout = string | { hsplit: Layout[] } | { vsplit: Layout[] };

function isHsplit(ly: Layout): ly is { hsplit: Layout[] } {
  return (ly as any).hsplit !== undefined;
}

function isVsplit(ly: Layout): ly is { vsplit: Layout[] } {
  return (ly as any).vsplit !== undefined;
}

function makeLayout(ly: Layout) {
  if (typeof (ly) === 'string') return <GridItem id={ly} />;
  if (isHsplit(ly)) return (
    <GridHbox>
      {React.Children.toArray(ly.hsplit.map(makeLayout))}
    </GridHbox>
  );
  if (isVsplit(ly)) return (
    <GridVbox>
      {React.Children.toArray(ly.vsplit.map(makeLayout))}
    </GridVbox>
  );
  return null;
}

function makeRootLayout(ly: Layout) {
  if (isVsplit(ly)) return (
    React.Children.toArray(ly.vsplit.map(makeLayout))
  );
  return makeLayout(ly);
}

export interface ViewLayoutProps extends ItemProps {
  /** Use this view by default. */
  defaultView?: boolean;
  /** View layout. */
  layout: Layout;
}

/** Register a new View. */
export function registerView(view: ViewLayoutProps) {
  const { id, label, title, defaultView, layout } = view;
  Lab.addLibraryItem('view', {
    id,
    label,
    title,
    defaultView,
    children: makeRootLayout(layout),
  });
}

/* --------------------------------------------------------------------------*/
/* --- Deprecated View                                                    ---*/
/* --------------------------------------------------------------------------*/

export interface ViewProps extends ContentProps {
  /** Use this view by default. */
  defaultView?: boolean;
}

/**
   Layout of LabView Components.
   Defines a predefined layout of components. The view is organized
   into a GridContent, which must _only_ consists of:
   - `<GridHbox>…</GridHbox>` an horizontal grid of `GridContent` elements;
   - `<GridVbox>…</GridVbox>` a vertical grid of `GridContent` elements;
   - `<GridItem id=…>` a single component.

   These grid content components must be imported from the `dome/layout/grids`
   module:
   ```
   import { GridItem, GridHbox, GridVbox } from 'dome/layout/grids';
   ```
   @deprecated Use [[registerView]] instead.
 */
export function View(props: ViewProps) {
  Lab.useLibraryItem('views', props);
  return null;
}

/* --------------------------------------------------------------------------*/
/* --- Components                                                         ---*/
/* --------------------------------------------------------------------------*/

export interface ComponentProps extends ContentProps {
  /** Group attachment. */
  group?: string;
  /** Ordering index. */
  rank?: number;
}

/**
   Register the given Ivette Component.
   Components are sorted by rank and identifier among each group.
 */
export function registerComponent(props: ComponentProps) {
  Lab.addLibraryItem('components', props);
}

/**
   LabView Component.
   Defines a component and its content when incorporated inside a view.
   Unless specified, the component will be implicitely attached
   to the current enclosing group. The `rank` property can be used
   for adjusting component ordering (see also `<Fragment/>` and `<Group/>`).
   @deprecated Use [[registerComponent]] instead.
 */
export function Component(props: ComponentProps) {
  Lab.useLibraryItem('components', props);
  return null;
}

export interface TitleBarProps {
  /*
     @property {string} [icon] - displayed icon
     @property {string} [label] - displayed name
     @property {string} [title] - description tooltip
     @property {React.Children} children - additional components to render
   */
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
