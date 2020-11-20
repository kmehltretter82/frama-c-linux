// --------------------------------------------------------------------------
// --- SideBars
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/frame/sidebars
*/

import React from 'react';
import { useFlipSettings } from 'dome';
import { Badge } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';
import { classes } from 'dome/misc/utils';

import './style.css';

// --------------------------------------------------------------------------
// --- SideBar Container
// --------------------------------------------------------------------------

export interface SideBarProps {
  className?: string;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}

/**
   Container for sidebar items.
 */
export function SideBar(props: SideBarProps) {
  const className = classes(
    'dome-xSideBar',
    'dome-color-frame',
    props.className,
  );
  return (
    <div className={className} style={props.style}>
      {props.children}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Badges Specifications
// --------------------------------------------------------------------------

export type BadgeElt = undefined | null | string | number | React.ReactNode;
export type Badge = BadgeElt | BadgeElt[];

const makeBadgeElt = (elt: BadgeElt): React.ReactNode => {
  if (elt === undefined || elt === null) return null;
  switch (typeof (elt)) {
    case 'number':
    case 'string':
      return <Badge value={elt} />;
    default:
      return elt;
  }
};

const makeBadge = (elt: Badge): React.ReactNode => {
  if (Array.isArray(elt))
    return elt.map(makeBadgeElt);
  return makeBadgeElt(elt);
};

// --------------------------------------------------------------------------
// --- SideBar Section Hide/Show Button
// --------------------------------------------------------------------------

const HideShow = (props: { onClick: () => void; visible: boolean }) => (
  <label
    className="dome-xSideBarSection-hideshow dome-text-label"
    onClick={props.onClick}
  >
    {props.visible ? 'Hide' : 'Show'}
  </label>
);

// --------------------------------------------------------------------------
// --- SideBar Section
// --------------------------------------------------------------------------

export interface SectionProps {
  /** Section label. */
  label: string;
  /** Section tooltip description. */
  title?: string;
  /** Hide/Show window settings. */
  settings?: string;
  /** Controlled Fold/Unfold state. */
  unfold?: boolean;
  /** Initial unfold state (default is `true`). */
  defaultUnfold?: boolean;
  /** Enabled sections are made visible. */
  enabled?: boolean;
  /** Disabled sections are made unvisible. */
  disabled?: boolean;
  /** Badge summary (only visible when folded). */
  summary?: Badge;
  /** Section contents. */
  children?: React.ReactNode;
}

/**
   Sidebar Section.

   Unless specified, sections can be hidden on click.
   When items in the section have badge(s)
   it is highly recommended to provide a badge summary to be displayed
   when the content is hidden.

   Sections with no items are not displayed.
*/
export function Section(props: SectionProps) {

  const [state, flipState] = useFlipSettings(
    props.settings,
    props.defaultUnfold,
  );

  const { enabled = true, disabled = false, children } = props;
  if (disabled || !enabled || React.Children.count(children) === 0)
    return null;
  const { unfold } = props;
  const foldable = unfold === undefined;
  const visible = unfold ?? state;
  const maxHeight = visible ? 'max-content' : 0;

  return (
    <div className="dome-xSideBarSection">
      <div className="dome-xSideBarSection-title" title={props.label}>
        <Label label={props.label} />
        {!visible && makeBadge(props.summary)}
        {foldable && <HideShow visible={visible} onClick={flipState} />}
      </div>
      <div className="dome-xSideBarSection-content" style={{ maxHeight }}>
        {children}
      </div>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- SideBar Items
// --------------------------------------------------------------------------

export interface ItemProps {
  /** Item icon. */
  icon?: string;
  /** Item label. */
  label?: string;
  /** Item tooltip text. */
  title?: string;
  /** Badge. */
  badge?: Badge;
  /** Enabled item. */
  enabled?: boolean;
  /** Disabled item (dimmed). */
  disabled?: boolean;
  /** Selection state. */
  selected?: boolean;
  /** Selection callback. */
  onSelection?: () => void;
  /** Right-click callback. */
  onContextMenu?: () => void;
  /** Other item elements. */
  children?: React.ReactNode;
}

/** Sidebar Items. */
export function Item(props: ItemProps) {
  const { selected = false, disabled = false, enabled = true } = props;
  const isDisabled = disabled || !enabled;
  const onClick = isDisabled ? undefined : props.onSelection;
  const onContextMenu = isDisabled ? undefined : props.onContextMenu;
  const className = classes(
    'dome-xSideBarItem',
    selected ? 'dome-active' : 'dome-inactive',
    isDisabled && 'dome-disabled',
  );
  return (
    <div
      className={className}
      title={props.title}
      onContextMenu={onContextMenu}
      onClick={onClick}
    >
      <Label icon={props.icon} label={props.label} />
      {props.children}
      {makeBadge(props.badge)}
    </div>
  );
}

// --------------------------------------------------------------------------
