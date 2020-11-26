// --------------------------------------------------------------------------
// --- ToolBars
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/frame/toolbars
 */

import React from 'react';
import { Event, useEvent, find } from 'dome';
import { debounce } from 'lodash';
import { SVG } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';
import { classes } from 'dome/misc/utils';
import './style.css';

// --------------------------------------------------------------------------
// --- ToolBar Container
// --------------------------------------------------------------------------

export interface ToolBarProps {
  className?: string;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}

/**
   @class
   @summary Container for toolbar items.
 */
export function ToolBar(props: ToolBarProps) {
  const { children } = props;
  const n = React.Children.count(children);
  if (n === 0) return null;
  const className = classes(
    'dome-xToolBar',
    'dome-color-frame',
    props.className,
  );
  return (
    <div className={className} style={props.style}>
      <div className="dome-xToolBar-inset" />
      {children}
      <div className="dome-xToolBar-inset" />
    </div>
  );
}

// --------------------------------------------------------------------------
// --- ToolBar Spaces
// --------------------------------------------------------------------------

/** Fixed (tiny) space. */
export const Inset = (() => <div className="dome-xToolBar-inset" />);

/** Fixed space. */
export const Space = (() => <div className="dome-xToolBar-space" />);

/** Auto-extensible space. */
export const Filler = (() => <div className="dome-xToolBar-filler" />);

/** Fixed space with vertical rule. */
export const Separator = () => (
  <div className="dome-xToolBar-separator">
    <div className="dome-xToolBar-vrule" />
  </div>
);

const SELECT = 'dome-xToolBar-control dome-selected';
const BUTTON = 'dome-xToolBar-control dome-color-frame';
const KIND = (kind: undefined | string) => (
  kind ? ` dome-xToolBar-${kind}` : ''
);

interface SELECT<A> {
  selected?: boolean;
  selection?: A;
  value?: A;
}

export type ButtonKind =
  | 'default' | 'cancel' | 'warning' | 'positive' | 'negative';

export interface ButtonProps<A> {
  /** Button icon, Cf. [gallery](gallery-icons.html). */
  icon?: string;
  /** Button label. */
  label?: string;
  /** Button tooltip text. */
  title?: string;
  /** Button kind. */
  kind?: ButtonKind;
  /** Enabled State (default `true`). */
  enabled?: boolean;
  /** Disabled State (default `false`). */
  disabled?: boolean;
  /** Selection State (defaults to `false` or `selection` equal to `value`). */
  selected?: boolean;
  /** Button's value. */
  value?: A;
  /** Currently selected value. */
  selection?: A;
  /** Selection callback. Receives the button's value. */
  onClick?: (value: A | undefined) => void;
}

/** Toolbar Button. */
export function Button<A = undefined>(props: ButtonProps<A>) {
  const { selected, value, selection, onClick } = props;
  const { enabled = true, disabled = false } = props;
  const isSelected = selected !== undefined
    ? selected
    : (value !== undefined && value === selection);
  return (
    <button
      type="button"
      disabled={disabled || !enabled}
      className={isSelected ? SELECT : (BUTTON + KIND(props.kind))}
      onClick={onClick && (() => onClick(value))}
      title={props.title}
    >
      {props.icon && <SVG id={props.icon} />}
      {props.label && <label>{props.label}</label>}
    </button>
  );
}

// --------------------------------------------------------------------------
// --- Selection Props
// --------------------------------------------------------------------------

export interface SelectionProps<A> {
  /** Enabled Group (default `true`). */
  enabled?: boolean;
  /** Disabled Group (default `false`). */
  disabled?: boolean;
  /** Currently selected button. */
  value?: A;
  /** Callback on clicked buttons. */
  onChange?: (value: undefined | A) => void;
  /** Buttons array. */
  children: React.ReactElement[];
}

// --------------------------------------------------------------------------
// --- ToolBar Button Group
// --------------------------------------------------------------------------

/**
   Toolbar Button Group.

   Properties of the button group are passed down the buttons of the group
   as appropriate defaults.
 */
export function ButtonGroup<A>(props: SelectionProps<A>) {
  const { children, value, onChange, enabled, disabled } = props;
  const baseProps: ButtonProps<A> = {
    enabled,
    disabled,
    selection: value,
    onClick: onChange,
  };
  return (
    <div className="dome-xToolBar-group">
      {React.Children.map(children, (elt) => React.cloneElement(
        elt,
        { ...baseProps, ...elt.props },
      ))}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- ToolBar Menu
// --------------------------------------------------------------------------

/** Toolbar Selector Menu.

   Behaves likes a standard `<select>` element, except that callback directly
   receives the select value, not the entire event.
   The list of options shall be given with standard
   `<option value={...} label={...}>` elements.
 */
export function Select(props: SelectionProps<string>) {
  const { enabled = true, disabled = false, onChange } = props;
  const callback = (evt: React.ChangeEvent<HTMLSelectElement>) => {
    if (onChange) onChange(evt.target.value);
  };
  return (
    <select
      className="dome-xToolBar-control dome-color-frame"
      value={props.value}
      disabled={disabled || !enabled}
      onChange={callback}
    >
      {props.children}
    </select>
  );
}

// --------------------------------------------------------------------------
// --- SearchField
// --------------------------------------------------------------------------

const DEBOUNCED_SEARCH = 200;

export interface Suggestion<A> {
  id: string | number;
  icon?: string;
  label: string | JSX.Element;
  title?: string;
  value: A;
}

export interface SearchFieldProps<A> {
  /** Tooltip Text. */
  title?: string;
  /** Placeholder Text. */
  placeholder?: string;
  /** Search Callback. */
  onSearch?: (pattern: string, suggestions: A[]) => void;
  /** Suggestions Callback. */
  onLookup?: (pattern: string) => Promise<Suggestion<A>[]>;
  /** Triggering Event (defaults to [[Dome.find]]). */
  event?: null | Event<void>;
}

/**
   Search Bar.
 */
export function SearchField<A>(props: SearchFieldProps<A>) {
  const { onLookup, event = find } = props;
  const inputRef = React.useRef<HTMLInputElement | null>(null);
  const blur = () => inputRef.current?.blur();
  const focus = () => inputRef.current?.focus();
  const [value, setValue] = React.useState('');
  const [items, setItems] = React.useState<Suggestion<A>[]>([]);

  // Find event trigger
  useEvent(event, focus);

  // Lookup trigger
  const triggerLookup = React.useCallback(debounce((pattern: string) => {
    if (onLookup) onLookup(pattern).then(setItems).catch();
  }, DEBOUNCED_SEARCH), [onLookup, setItems]);

  // Blur Event
  const onBlur = () => {
    setValue('');
    setItems([]);
  };

  // Key Events
  const onKeyUp = (evt: React.KeyboardEvent) => {
    if (evt.key === 'Escape') blur();
    if (evt.key === 'Enter') {
      const callback = props.onSearch;
      if (callback) callback(value, items.map((s) => s.value));
      blur();
    }
  };

  // Input Events
  const onChange = (evt: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = evt.target.value;
    triggerLookup(newValue);
    setValue(newValue);
  };

  // Render Suggestions
  const suggestions = items.map((s) => (
    <Label
      key={s.id}
      icon={s.icon}
      title={s.title}
      className="dome-xToolBar-searchitem"
    >
      {s.label}
    </Label>
  ));
  const haspopup = value !== '' && suggestions.length > 0;
  const visibility = haspopup ? 'visible' : 'hidden';

  // Render Component
  return (
    <>
      <div className="dome-xToolBar-searchicon">
        <SVG id="SEARCH" />
        <div
          style={{ visibility }}
          className="dome-xToolBar-searchmenu"
        >
          {suggestions}
        </div>
      </div>
      <input
        ref={inputRef}
        type="search"
        title={props.title}
        value={value}
        placeholder={props.placeholder}
        className="dome-xToolBar-control dome-xToolBar-searchfield"
        onKeyUp={onKeyUp}
        onChange={onChange}
        onBlur={onBlur}
      />
    </>
  );
}

// --------------------------------------------------------------------------
