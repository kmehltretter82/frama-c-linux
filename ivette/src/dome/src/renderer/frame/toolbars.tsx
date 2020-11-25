// --------------------------------------------------------------------------
// --- ToolBars
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/frame/toolbars
 */

import React from 'react';
import { SVG } from 'dome/controls/icons';
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

export interface SearchFieldProps {
  /** Tooltip Text */
  title?: string;
  /** Placeholder Text */
  placeholder?: string;
}

export function SearchField(props: SearchFieldProps) {
  const inputRef = React.useRef<HTMLInputElement | null>(null);
  const [value, setValue] = React.useState('');
  const forceBlur = () => inputRef?.current?.blur();
  const onBlur = () => setValue('');
  const onKeyUp = (evt: React.KeyboardEvent) => {
    if (evt.key === 'Escape') forceBlur();
    if (evt.key === 'Enter') {
      console.log('ENTER', value);
      forceBlur();
    }
  };
  const onChange = (evt: React.ChangeEvent<HTMLInputElement>) => {
    setValue(evt.target.value);
  };
  console.log('VALUE', value);
  return (
    <>
      <div className="dome-xToolBar-searchicon">
        <SVG id="SEARCH" />
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
