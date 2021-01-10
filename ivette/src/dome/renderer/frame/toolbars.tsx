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
  /** Button is displayed (default `true`). */
  visible?: boolean;
  /** Button is hidden (default `false`). */
  hidden?: boolean;
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
  const { visible = true, hidden = false } = props;
  if (!visible || hidden) return null;
  const { enabled = true, disabled = false } = props;
  const { selected, value, selection, onClick } = props;
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

export interface ButtonGroupProps<A> extends SelectionProps<A> {
  className?: string;
  style?: React.CSSProperties;
}

/**
   Toolbar Button Group.

   Properties of the button group are passed down the buttons of the group
   as appropriate defaults.
 */
export function ButtonGroup<A>(props: ButtonGroupProps<A>) {
  const { children, value, onChange, enabled, disabled } = props;
  const baseProps: ButtonProps<A> = {
    enabled,
    disabled,
    selection: value,
    onClick: onChange,
  };
  const className = classes('dome-xToolBar-group', props.className);
  return (
    <div className={className} style={props.style}>
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

const scrollToRef = (r: undefined | HTMLLabelElement) => {
  if (r) r.scrollIntoView({ block: 'nearest' });
};

export interface Hint<A> {
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
  /** Provided search hints (with respect to last `onSearch()` callback). */
  hints?: Hint<A>[];
  /** Search callback. Triggered on Enter Key, Escape Key or Blur event. */
  onSelect?: (pattern: string) => void;
  /** Dynamic search callback. Triggered on key pressed (debounced). */
  onSearch?: (pattern: string) => void;
  /** Hint selection callback. */
  onHint?: (hint: Hint<A>) => void;
  /** Event that triggers a focus request (defaults to [[dome.find]]). */
  event?: null | Event<void>;
}

/**
   Search Bar.
 */
export function SearchField<A = undefined>(props: SearchFieldProps<A>) {
  const inputRef = React.useRef<HTMLInputElement | null>(null);
  const blur = () => inputRef.current?.blur();
  const focus = () => inputRef.current?.focus();
  const [value, setValue] = React.useState('');
  const [index, setIndex] = React.useState(-1);
  const { onHint, onSelect, onSearch, hints = [] } = props;

  // Find event trigger
  useEvent(props.event ?? find, focus);

  // Lookup trigger
  const triggerLookup = React.useCallback(
    debounce((pattern: string) => {
      if (onSearch) onSearch(pattern);
    }, DEBOUNCED_SEARCH),
    [onSearch],
  );

  // Blur Event
  const onBlur = () => {
    setValue('');
    setIndex(-1);
    if (onSearch) onSearch('');
  };

  // Key Events
  const onKey = (evt: React.KeyboardEvent) => {
    switch (evt.key) {
      case 'Escape':
        blur();
        break;
      case 'Enter':
        if (index >= 0 && index < hints.length) {
          if (onHint) onHint(hints[index]);
        } else if (onSelect) onSelect(value);
        blur();
        break;
      case 'ArrowUp':
        if (index < 0) setIndex(hints.length - 1);
        if (index > 0) setIndex(index - 1);
        break;
      case 'ArrowDown':
        if (index < 0 && 0 < hints.length) setIndex(0);
        if (0 <= index && index < hints.length - 1) setIndex(index + 1);
        break;
    }
  };

  // Input Events
  const onChange = (evt: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = evt.target.value;
    triggerLookup(newValue);
    setIndex(-1);
    setValue(newValue);
  };

  // Render Suggestions
  const suggestions = hints.map((h, k) => {
    const selected = k === index || hints.length === 1;
    const className = classes(
      'dome-xToolBar-searchitem',
      selected && 'dome-xToolBar-searchindex',
    );
    return (
      <Label
        ref={selected ? scrollToRef : undefined}
        key={h.id}
        icon={h.icon}
        title={h.title}
        className={className}
        onClick={() => {
          if (onHint) onHint(h);
          blur();
        }}
      >
        {h.label}
      </Label>
    );
  });
  const haspopup =
    inputRef.current === document.activeElement
    && suggestions.length > 0;
  const visibility = haspopup ? 'visible' : 'hidden';

  // Render Component
  return (
    <>
      <div className="dome-xToolBar-searchicon">
        <SVG id="SEARCH" />
        <div
          style={{ visibility }}
          className="dome-xToolBar-searchmenu"
          onMouseDown={(event) => event.preventDefault()}
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
        onKeyUp={onKey}
        onChange={onChange}
        onBlur={onBlur}
      />
    </>
  );
}

// --------------------------------------------------------------------------
