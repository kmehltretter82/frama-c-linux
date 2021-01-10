// --------------------------------------------------------------------------
// ---  Lab View Component
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module ivette
 */

import React from 'react';
import { Label } from 'dome/controls/labels';
import { DefineElement } from 'dome/layout/dispatch';
import {
  Rankify,
  useGroupContext,
  useLibraryItem,
  useTitleContext,
} from 'ivette@lab';

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
 */
export function Fragment(props: FragmentProps) {
  const { group, rank, children } = props;
  const context = useGroupContext();
  const base = context.order ?? [];
  return (
    <Rankify
      group={group ?? context.group}
      order={rank === undefined ? base : [...base, rank]}
    >
      {children}
    </Rankify>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Groups                                                             ---*/
/* --------------------------------------------------------------------------*/

export interface ItemProps {
  /** Identifier. */
  id: string;
  /** Displayed name. */
  label: string;
  /** Tooltip description. */
  title?: string;
  /** Contents. */
  children?: React.ReactNode;
}

/**
   Defines a group of components. The components rendered
   _inside_ its content are implicitely affected to this group,
   unless specified. The group content are also rendered
   in their specified order. For nested collections of components,
   use `<Fragment/>` instead of `<React.Fragment/>` to specify order.
 */
export function Group(props: ItemProps) {
  const { children, ...group } = props;
  const context = useLibraryItem('groups', group);
  return (
    <Rankify
      group={props.id}
      order={context.order ?? []}
    >
      {children}
    </Rankify>
  );
}

// --------------------------------------------------------------------------
// --- Views
// --------------------------------------------------------------------------

export interface ViewProps extends ItemProps {
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
 */
export function View(props: ViewProps) {
  useLibraryItem('views', props);
  return null;
}

// --------------------------------------------------------------------------
// --- Components
// --------------------------------------------------------------------------

export interface ComponentProps extends ItemProps {
  /** Group attachment (defaults to group context) */
  group?: string;
  /** Ordering index (defaults to fragment context). */
  rank?: number;
}

/**
   LabView Component.
   Defines a component and its content when incorporated inside a view.
   Unless specified, the component will be implicitely attached
   to the current enclosing group. The `rank` property can be used
   for adjusting component ordering (see also `<Fragment/>` and `<Group/>`).
 */
export function Component(props: ComponentProps) {
  useLibraryItem('components', props);
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
  const context = useTitleContext();
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

// --------------------------------------------------------------------------
