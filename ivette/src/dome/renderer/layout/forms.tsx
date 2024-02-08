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

/* --------------------------------------------------------------------------*/
/* --- Form Fields                                                        ---*/
/* --------------------------------------------------------------------------*/

/**
   Form Fields are made of states and fields, arranged into a form page.

   Field states are typically build with [[useState]] and [[useProperty]]
   hooks, also you can also build them manually. All the provided hooks
   can be used and composed with each other to build full feature states.

   Form fields shall be arranged into sections and form pages to obtain a
   wellformed layout.

   @packageDocumentation
   @module dome/layout/form
 */

import { debounce } from 'lodash';
import Events from 'events';
import React from 'react';
import * as Dome from 'dome';
import * as Utils from 'dome/misc/utils';
import { SVG } from 'dome/controls/icons';
import { Checkbox, Radio, Select as SelectMenu } from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';

export type FieldError =
  | undefined | boolean | string
  | { [key: string]: FieldError } | FieldError[];
export type Checker<A> = (value: A) => boolean | FieldError;
export type Callback<A> = (value: A, error: FieldError) => void;

export interface FieldState<A> {
  value: A;
  error?: FieldError;
  reset?: A;
  onChanged: Callback<A>;
}

/* --------------------------------------------------------------------------*/
/* --- State Errors Utilities                                             ---*/
/* --------------------------------------------------------------------------*/

export function inRange(
  a: number,
  b: number,
): Checker<number> {
  return (v: number) => (a <= v && v <= b);
}

export function validate<A>(
  value: A,
  checker: undefined | Checker<A>,
): FieldError {
  if (checker) {
    try {
      const r = checker(value);
      if (r === undefined || r === true) return undefined;
      return r;
    } catch (err) {
      return `${err}`;
    }
  }
  return undefined;
}

export function isValid(err: FieldError): boolean { return !err; }

type ObjectError = { [key: string]: FieldError };

function isObjectError(err: FieldError): err is ObjectError {
  return typeof err === 'object' && !Array.isArray(err);
}

function isArrayError(err: FieldError): err is FieldError[] {
  return Array.isArray(err);
}

function isValidObject(err: ObjectError): boolean {
  const ks = Object.keys(err);
  for (let k = 0; k < ks.length; k++) {
    if (!isValid(err[ks[k]])) return false;
  }
  return true;
}

function isValidArray(err: FieldError[]): boolean {
  for (let k = 0; k < err.length; k++) {
    if (!isValid(err[k])) return false;
  }
  return true;
}

/* --------------------------------------------------------------------------*/
/* --- Reset Hooks                                                        ---*/
/* --------------------------------------------------------------------------*/

export type ResetCallback = () => void;

/**
   Controller for _buffered_ field states.
 */
export class BufferController {
  private readonly evt = new Events();

  /** Notify all reset listener events. */
  reset(): void { this.evt.emit('reset'); }

  /** Notify all commit listener events. */
  commit(): void { this.evt.emit('commit'); }

  /** There are active listeners for Reset event. */
  hasReset(): boolean { return this.evt.listenerCount('reset') > 0; }

  /** There are active listeners for Commit event. */
  hasCommit(): boolean { return this.evt.listenerCount('commit') > 0; }

  /** @internal */
  onReset(fn: ResetCallback): void { this.evt.addListener('reset', fn); }

  /** @internal */
  offReset(fn: ResetCallback): void { this.evt.addListener('reset', fn); }

  /** @internal */
  onCommit(fn: ResetCallback): void { this.evt.addListener('commit', fn); }

  /** @internal */
  offCommit(fn: ResetCallback): void { this.evt.addListener('commit', fn); }

}

/**
   Insert a temporary buffer to stack modifications. Values are imported from
   the input state, and modifications are stacked into an internal buffer.

   The buffered state will perform the following actions
   upon remote control events:

   - on Reset event, the buffered state is restored to the input value.

   - on Commit event, the buffered state is sent to the input callback.

   The returned field state reflects the internal buffer state. Its local
   reset value is either the input reset value or the current input value.

 */
export function useBuffer<A>(
  remote : BufferController,
  state: FieldState<A>
): FieldState<A>
{
  const { value, error, reset, onChanged } = state;
  const [ modified, setModified ] = React.useState(false);
  const [ buffer, setBuffer ] = React.useState<A>(value);
  const [ berror, setBerror ] = React.useState<FieldError>(error);
  const staged = modified && !berror;

  // --- Reset
  React.useEffect(() => {
    if (modified) {
      const doReset = (): void => {
        setModified(false);
        setBuffer(value);
        setBerror(error);
      };
      remote.onReset(doReset);
      return () => remote.offReset(doReset);
    } else return;
  }, [remote, modified, value, error]);

  // --- Commit
  React.useEffect(() => {
    if (staged) {
      const doCommit = (): void => {
        setModified(false);
        onChanged(buffer, undefined);
      };
      remote.onCommit(doCommit);
      return () => remote.offCommit(doCommit);
    } else return;
  }, [remote, staged, buffer, onChanged]);

  // --- Callback
  const onLocalChange = React.useCallback(
    (newValue, newError) => {
      setModified(true);
      setBuffer(newValue);
      setBerror(newError);
    }, []);

  return {
    value: modified ? buffer : value,
    error: modified ? berror : error,
    reset: reset ?? (modified ? value : undefined),
    onChanged: onLocalChange,
  };
}

/* --------------------------------------------------------------------------*/
/* --- State Hooks                                                        ---*/
/* --------------------------------------------------------------------------*/

/** Create a local field state, like `React.useState()` does. */
export function useState<A>(
  defaultValue: A,
  checker?: Checker<A>,
  onChange?: Callback<A>,
): FieldState<A> {
  const [value, setValue] = React.useState<A>(defaultValue);
  const [error, setError] = React.useState<FieldError>(undefined);
  const onChanged = React.useCallback((newValue: A, newError: FieldError) => {
    const localError = validate(newValue, checker) || newError;
    setValue(newValue);
    setError(localError);
    if (onChange) onChange(newValue, localError);
  }, [checker, setValue, setError, onChange]);
  return { value, error, onChanged };
}

/** Introduces a local state and propagates only non-errors. */
export function useValid<A>(
  state: [A, (newValue: A) => void],
): FieldState<A> {
  const [value, setValue] = state;
  const [local, setLocal] = React.useState(value);
  const [error, setError] = React.useState<FieldError>(undefined);
  const update = React.useCallback(
    (newValue: A, newError: FieldError) => {
      setLocal(newValue);
      setError(newError);
      if (!newError) setValue(newValue);
    }, [setValue],
  );
  return {
    value: error ? local : value,
    error,
    reset: value,
    onChanged: update
  };
}

/** Provides a new state with a default value. */
export function useDefault<A>(
  state: FieldState<A | undefined>,
  defaultValue: A,
): FieldState<A> {
  const { value, error, reset, onChanged } = state;
  return { value: value ?? defaultValue, error, reset, onChanged };
}

/**
   Coerces a state with defined value
   into some with possibly undefined one.
 */
export function useDefined<A>(
  state: FieldState<A>,
): FieldState<A | undefined> {
  const { value, error, reset, onChanged } = state;
  const update = React.useCallback(
    (newValue: A | undefined, newError: FieldError) => {
      if (newValue !== undefined) {
        onChanged(newValue, newError);
      }
    }, [onChanged],
  );
  return { value, error, reset, onChanged: update };
}

/**
   Undefined value leads to an error.
   @param onError - error message in case of undefined or invalid updates.
 */
export function useRequired<A>(
  state: FieldState<A>,
  onError?: string,
): FieldState<A | undefined> {
  const { value, error, reset, onChanged } = state;
  const cache = React.useRef(value);
  const update = React.useCallback(
    (newValue: A | undefined, newError: FieldError) => {
      if (newValue === undefined) {
        onChanged(cache.current, onError || 'Required field');
      } else {
        onChanged(newValue, newError);
      }
    }, [cache, onError, onChanged],
  );
  return { value, error, reset, onChanged: update };
}

/**
   Enrich the state with a local checker.
   The local error, if any, has precedence over any error from updates.
 */
export function useChecker<A>(
  state: FieldState<A>,
  checker?: Checker<A>,
): FieldState<A> {
  const { value, error, reset, onChanged } = state;
  const update = React.useCallback((newValue: A, newError: FieldError) => {
    const localError = validate(newValue, checker) || newError;
    onChanged(newValue, localError);
  }, [checker, onChanged]);
  return { value, error, reset, onChanged: update };
}

/**
   Transform a state `A` into a state `B` through converting functions.

   Input and output functions shall be the inverse with each others.

   In case an exception is raised during input conversion, state `B`
   retains its previous value (or default value) but forwards
   the translation error.

   In case an exception is raised during output conversion, a local state
   is maintained with the invalid `B` value until it is transformed into
   a valid one.

   @param input - converting function from `A` to `B`
   @param output - converting function from `B` to `A`
 */

export function useFilter<A, B>(
  state: FieldState<A>,
  input: (value: A) => B,
  output: (value: B) => A,
  defaultValue: B,
): FieldState<B> {

  const { value, error, reset, onChanged } = state;
  const [localValue, setLocalValue] = React.useState(defaultValue);
  const [localError, setLocalError] = React.useState<FieldError>(undefined);
  const [dangling, setDangling] = React.useState(false);

  const update = React.useCallback(
    (newValue: B, newError: FieldError) => {
      try {
        const outValue = output(newValue);
        setLocalValue(newValue);
        setLocalError(newError);
        if (isValid(newError)) {
          setDangling(false);
          onChanged(outValue, undefined);
        }
      } catch (err) {
        setLocalValue(newValue);
        setLocalError(newError || err ? `${err}` : 'Invalid value');
        setDangling(true);
      }
    }, [output, onChanged, setLocalValue, setLocalError],
  );

  const ConvertedReset = ((val: A | undefined): B | undefined => {
    if(typeof val === "undefined") return val;
    try { return input(val); }
    catch { return undefined; }
  })(reset);

  if (dangling) {
    return {
      value: localValue,
      error: localError,
      reset: ConvertedReset,
      onChanged: update
    };
  }
  try {
    return {
      value: input(value),
      error,
      reset: ConvertedReset,
      onChanged: update
    };
  } catch (err) {
    return {
      value: localValue,
      error: err ? `${err}` : 'Invalid input',
      reset: ConvertedReset,
      onChanged: update
    };
  }

}

/**
   Introduces a latency between local changes and propagated ones.
   A transient local state is maintained during debounced updates, until
   the last update is finally flushed.
 */
export function useLatency<A>(
  state: FieldState<A>,
  latency?: number,
): FieldState<A> {
  const { value, error, reset, onChanged } = state;
  const period = latency ?? 0;
  const [localValue, setLocalValue] = React.useState(value);
  const [localError, setLocalError] = React.useState(error);
  const [dangling, setDangling] = React.useState(false);
  const update = React.useMemo(() => {
    if (period > 0) {
      const propagate = debounce(
        (lateValue: A, lateError: FieldError) => {
          onChanged(lateValue, lateError);
          setDangling(false);
        }, period,
      );
      return (newValue: A, newError: FieldError) => {
        setLocalValue(newValue);
        setLocalError(newError);
        setDangling(true);
        propagate(newValue, newError);
      };
    }
    setDangling(false);
    return onChanged;
  }, [period, setDangling, onChanged, setLocalValue, setLocalError]);
  return {
    value: dangling ? localValue : value,
    error: dangling ? localError : error,
    reset,
    onChanged: update,
  };
}

/**
   Returns the state associated to a property of the input state.
 */
export function useProperty<A, K extends keyof A>(
  state: FieldState<A>,
  property: K,
  checker?: Checker<A[K]>,
): FieldState<A[K]> {
  const { value, error, reset, onChanged } = state;
  const update = React.useCallback((newProp: A[K], newError: FieldError) => {
    const newValue = { ...value, [property]: newProp };
    const objError = isObjectError(error) ? error : {};
    const propError = validate(newProp, checker) || newError;
    const localError = { ...objError, [property]: propError };
    onChanged(newValue, isValidObject(localError) ? undefined : localError);
  }, [value, error, onChanged, property, checker, ]);

  return {
    value: value[property],
    error: isObjectError(error) ? error[property] : undefined,
    reset: reset && reset[property],
    onChanged: update
  };
}

/**
   Returns the state associated to an index element of the input state.
 */
export function useIndex<A>(
  state: FieldState<A[]>,
  index: number,
  checker?: Checker<A>,
): FieldState<A> {
  const { value, error, reset, onChanged } = state;
  const update = React.useCallback((newValue: A, newError: FieldError) => {
    const newArray = value.slice();
    newArray[index] = newValue;
    const localError = isArrayError(error) ? error.slice() : [];
    const valueError = validate(newValue, checker) || newError;
    localError[index] = valueError;
    onChanged(newArray, isValidArray(localError) ? undefined : localError);
  }, [value, error, onChanged, index, checker]);
  const itemError = isArrayError(error) ? error[index] : undefined;
  return {
    value: value[index],
    error: itemError,
    reset: reset && reset[index],
    onChanged: update
  };
}

/* --------------------------------------------------------------------------*/
/* --- Form Filter Context                                                ---*/
/* --------------------------------------------------------------------------*/

export interface FilterProps {
  /** default is false. */
  hidden?: boolean;
  /** default is true. */
  visible?: boolean;
  /** default is true. */
  enabled?: boolean;
  /** default is false. */
  disabled?: boolean;
}

export interface Children { children?: React.ReactNode }

interface FormContext {
  disabled: boolean;
  hidden: boolean;
}

const CONTEXT = React.createContext<FormContext | undefined>(undefined);

const HIDDEN =
  ({ hidden = false, visible = true }: FilterProps): boolean =>
    hidden || !visible;

const DISABLED =
  ({ disabled = false, enabled = true }: FilterProps): boolean =>
    disabled || !enabled;

function useContext(props?: FilterProps): FormContext {
  const Parent = React.useContext(CONTEXT);
  return {
    hidden: (props && HIDDEN(props)) || (Parent?.hidden ?? false),
    disabled: (props && DISABLED(props)) || (Parent?.disabled ?? false),
  };
}

/**
   Allow to locally disable or hide all its children fields.
   @category Form Containers
*/
export function FormFilter(props: FilterProps & Children): JSX.Element | null {
  const context = useContext(props);
  if (context.hidden) return null;
  return (
    <CONTEXT.Provider value={context}>
      {props.children}
    </CONTEXT.Provider>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Main Form Container                                                ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Containers */
export interface PageProps extends FilterProps, Children {
  /** Additional container class. */
  className?: string;
  /** Additional container style. */
  style?: React.CSSProperties;
}

/**
   Main Form Container.
   @category Form Containers
 */
export function Page(props: PageProps): JSX.Element | null {
  const { className, style, children, ...filter } = props;
  const { hidden, disabled } = useContext(filter);
  const css = Utils.classes(className ?? 'dome-xForm-grid');
  if (hidden) return null;
  return (
    <div className={css} style={style}>
      <CONTEXT.Provider value={{ hidden, disabled }}>
        {children}
      </CONTEXT.Provider>
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Warning Badge
// --------------------------------------------------------------------------

export interface WarningProps {
  /** Short warning message (displayed on hover). */
  warning?: string;
  /** Error details (if a string is provided, in tooltip). */
  error?: FieldError;
  /** Label offset. */
  offset?: number;
}

/** Warning Badge. */
export function Warning(props: WarningProps): JSX.Element {
  const { warning, error, offset = 0 } = props;
  const DETAILS = typeof error === 'string' ? error : undefined;
  const WARNING = warning && (
    <span className="dome-xForm-warning">
      {warning}
    </span>
  );
  return (
    <div
      className="dome-xIcon dome-xForm-error"
      style={{ top: offset - 2 }}
      title={DETAILS}
    >
      <SVG id="WARNING" size={11} />
      {WARNING}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Block Container
// --------------------------------------------------------------------------

/**
   Layout its contents inside a full-width container.
   @category Form Containers
 */
export function FormBlock(props: FilterProps & Children): JSX.Element {
  const { children, ...filter } = props;
  return (
    <FormFilter {...filter}>
      <div className="dome-xForm-block">
        {children}
      </div>
    </FormFilter>
  );
}

// --------------------------------------------------------------------------
// --- Section Container
// --------------------------------------------------------------------------

/** @category Form Fields */
export interface SectionProps extends FilterProps, Children {
  /** Section name. */
  label: string;
  /** Tooltip text. */
  title?: string;
  /** Warning Error (when unfolded). */
  warning?: string;
  /** Associated Error. */
  error?: FieldError;
  /** Fold/Unfold settings. */
  settings?: string;
  /** Fold/Unfold state (defaults to false). */
  unfold?: boolean;
}

/** @category Form Fields */
export function Section(props: SectionProps): JSX.Element | null {
  const { label, title, children, warning, error, ...filter } = props;
  const { disabled, hidden } = useContext(filter);
  const [unfold, flip] = Dome.useFlipSettings(props.settings, props.unfold);

  if (hidden) return null;

  const hasWarning = unfold && !disabled && error;

  const cssTitle = Utils.classes(
    'dome-text-title',
    disabled && 'dome-disabled',
  );

  return (
    <CONTEXT.Provider value={{ hidden, disabled }}>
      <div className="dome-xForm-section" onClick={flip}>
        <div className="dome-xForm-fold">
          <SVG id={unfold ? 'TRIANGLE.DOWN' : 'TRIANGLE.RIGHT'} size={11} />
        </div>
        <label className={cssTitle} title={title}>
          {label}
        </label>
        {hasWarning && <Warning warning={warning} />}
      </div>
      {unfold && children}
      {unfold && <div className="dome-xForm-hsep" />}
    </CONTEXT.Provider>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Generic Field                                                     --- */
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export interface GenericFieldProps extends FilterProps, Children {
  /** Field label. */
  label: string;
  /** Field tooltip text. */
  title?: string;
  /** Field offset. */
  offset?: number;
  /** Html tag `<input />` element. */
  htmlFor?: string;
  /** Warning message (in case of error). */
  onError?: string;
  /** Error (if any). */
  error?: FieldError;
}

let FIELDID = 0;

/** Generates a unique, stable identifier. */
export function useHtmlFor(): string {
  return React.useMemo(() => `dome-field-${FIELDID++}`, []);
}

/**
   Generic Field.
   Layout its content in a top-left aligned box on the right of the label.
   @category Form Fields
 */
export function Field(props: GenericFieldProps): JSX.Element | null {
  const { hidden, disabled } = useContext(props);

  if (hidden) return null;

  const { label, title, offset, htmlFor, children } = props;

  const cssLabel = Utils.classes(
    'dome-xForm-label dome-text-label',
    disabled && 'dome-disabled',
  );

  const cssField = Utils.classes(
    'dome-xForm-field dome-text-label',
    disabled && 'dome-disabled',
  );

  const { onError, error } = props;

  const WARNING = error ? (
    <Warning offset={offset} warning={onError} error={error} />
  ) : null;

  return (
    <>
      <Label
        className={cssLabel}
        style={{ top: offset }}
        htmlFor={htmlFor}
        title={title}
        label={label}
      />
      <div className={cssField} title={title}>
        {children}
        {WARNING}
      </div>
    </>
  );

}

/* --------------------------------------------------------------------------*/
/* --- Input Fields                                                       ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export interface FieldProps<A> extends FilterProps {
  /** Field label. */
  label: string;
  /** Field tooltip text. */
  title?: string;
  /** Field state. */
  state: FieldState<A>;
  /** Checker. */
  checker?: Checker<A>;
  /** Alternative error message (in case of error). */
  onError?: string;
}

type InputEvent = { target: { value: string } };
type InputState = [string, FieldError, (evt: InputEvent) => void];

function useChangeEvent(onChanged: Callback<string>)
: ((evt: InputEvent) => void) {
  return React.useCallback(
    (evt: InputEvent) => { onChanged(evt.target.value, undefined); },
    [onChanged],
  );
}

/* --------------------------------------------------------------------------*/
/* --- Text Fields                                                        ---*/
/* --------------------------------------------------------------------------*/

/** @category Text Fields */
export interface TextFieldProps extends FieldProps<string | undefined> {
  placeholder?: string;
  className?: string;
  style?: React.CSSProperties;
  latency?: number;
}

function useTextInputField(
  props: TextFieldProps,
  defaultLatency: number,
): InputState {
  const checked = useChecker(props.state, props.checker);
  const period = props.latency ?? defaultLatency;
  const { value, error, onChanged } = useLatency(checked, period);
  const onChange = useChangeEvent(onChanged);
  return [value || '', error, onChange];
}

/**
   Text Field.
   @category Text Fields
 */
export function TextField(props: TextFieldProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const css = Utils.classes('dome-xForm-text-field', props.className);
  const [value, error, onChange] = useTextInputField(props, 600);
  return (
    <Field
      {...props}
      offset={4}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="text"
        value={value}
        className={css}
        style={props.style}
        disabled={disabled}
        placeholder={props.placeholder}
        onChange={onChange}
      />
    </Field>
  );
}

/**
   Monospaced Text Field.
   @category Text Fields
 */
export function TextCodeField(props: TextFieldProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const [value, error, onChange] = useTextInputField(props, 600);
  const css = Utils.classes(
    'dome-xForm-text-field',
    'dome-text-code',
    props.className,
  );
  return (
    <Field
      {...props}
      offset={4}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="text"
        value={value}
        className={css}
        style={props.style}
        disabled={disabled}
        placeholder={props.placeholder}
        onChange={onChange}
      />
    </Field>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Text Area Fields                                                   ---*/
/* --------------------------------------------------------------------------*/

/** @category Text Fields */
export interface TextFieldAreaProps extends TextFieldProps {
  /** Number of columns (default 35, min 5). */
  cols?: number;
  /** Number of rows (default 5, min 2). */
  rows?: number;
}

/**
   Text Field Area.
   @category Text Fields
 */
export function TextFieldArea(props: TextFieldAreaProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const [value, error, onChange] = useTextInputField(props, 900);
  const cols = Math.max(5, props.cols ?? 35);
  const rows = Math.max(2, props.rows ?? 5);
  const css = Utils.classes(
    'dome-xForm-textarea-field',
    props.className,
  );
  return (
    <Field
      {...props}
      offset={4}
      htmlFor={id}
      error={error}
    >
      <textarea
        id={id}
        wrap="hard"
        spellCheck
        value={value}
        cols={cols}
        rows={rows - 1}
        className={css}
        style={props.style}
        disabled={disabled}
        placeholder={props.placeholder}
        onChange={onChange}
      />
    </Field>
  );
}

/**
   Monospaced Text Field Area.
   @category Text Fields
 */
export function TextCodeFieldArea(props: TextFieldAreaProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const [value, error, onChange] = useTextInputField(props, 900);
  const cols = Math.max(5, props.cols ?? 35);
  const rows = Math.max(2, props.rows ?? 5);
  const css = Utils.classes(
    'dome-xForm-textarea-field',
    'dome-text-code',
    props.className,
  );
  return (
    <Field
      {...props}
      offset={4}
      htmlFor={id}
      error={error}
    >
      <textarea
        id={id}
        wrap="off"
        spellCheck={false}
        value={value}
        cols={cols}
        rows={rows}
        className={css}
        style={props.style}
        disabled={disabled}
        placeholder={props.placeholder}
        onChange={onChange}
      />
    </Field>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Number Field                                                       ---*/
/* --------------------------------------------------------------------------*/

/** @category Number Fields */
export interface NumberFieldProps extends FieldProps<number | undefined> {
  units?: string;
  placeholder?: string;
  className?: string;
  style?: React.CSSProperties;
  latency?: number;
}

function TEXT_OF_NUMBER(n: number | undefined): string {
  if (n === undefined) return '';
  if (Number.isNaN(n)) throw new Error('Invalid number');
  return Number(n).toLocaleString('en');
}

function TEXT_OF_INPUT_NUMBER(n: number | undefined): string {
  if (n === undefined) return '';
  if (Number.isNaN(n)) throw new Error('Invalid number');
  return Number(n).toString();
}

function NUMBER_OF_TEXT(s: string): number | undefined {
  if (s === '') return undefined;
  const n = Number.parseFloat(s.replace(/[ ,]/g, ''));
  if (Number.isNaN(n)) throw new Error('Invalid number');
  return n;
}

/**
   Text Field for Numbers.
   @category Number Fields
 */
export function NumberField(props: NumberFieldProps): JSX.Element {
  const { units, latency = 600 } = props;
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const css = Utils.classes('dome-xForm-number-field', props.className);
  const checked = useChecker(props.state, props.checker);
  const filtered = useFilter(checked, TEXT_OF_NUMBER, NUMBER_OF_TEXT, '');
  const { value, error, onChanged } = useLatency(filtered, latency);
  const onChange = useChangeEvent(onChanged);
  const UNITS = units && (
    <label className="dome-text-label dome-xForm-units">{units}</label>
  );
  return (
    <Field
      {...props}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="text"
        value={value}
        className={css}
        style={props.style}
        disabled={disabled}
        placeholder={props.placeholder}
        onChange={onChange}
      />
      {UNITS}
    </Field>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Spinner Field                                                      ---*/
/* --------------------------------------------------------------------------*/

/** @category Number Fields */
export interface SpinnerFieldProps extends NumberFieldProps {
  units?: string;
  /** Minimum value (included). */
  min: number;
  /** Maximum value (included). */
  max: number;
  /** Stepper increment (defaults 1). */
  step?: number;
}

/**
   Spinner Field
   @category Number Fields
 */
export function SpinnerField(props: SpinnerFieldProps): JSX.Element {
  const { units, min, max, step = 1, latency = 600, checker } = props;
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const css = Utils.classes('dome-xForm-spinner-field', props.className);
  const fullChecker = React.useCallback((v: number | undefined) => {
    if (v !== undefined && min <= v && v <= max) {
      return checker ? checker(v) : true;
    }
    return `Range ${min}…${max}`;

  }, [min, max, checker]);
  const checked = useChecker(props.state, fullChecker);
  const filtered = useFilter(checked, TEXT_OF_INPUT_NUMBER, NUMBER_OF_TEXT, '');
  const { value, error, onChanged } = useLatency(filtered, latency);
  const onChange = useChangeEvent(onChanged);
  const UNITS = units && (
    <label className="dome-text-label dome-xForm-units">{units}</label>
  );
  return (
    <Field
      {...props}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="number"
        value={value}
        min={min}
        max={max}
        step={step}
        className={css}
        style={props.style}
        disabled={disabled}
        placeholder={props.placeholder}
        onChange={onChange}
      />
      {UNITS}
    </Field>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Slider Field                                                       ---*/
/* --------------------------------------------------------------------------*/

/** @category Number Fields */
export interface SliderFieldProps extends FieldProps<number> {
  /** Minimal value (included). */
  min: number;
  /** Maximal value (included). */
  max: number;
  /** Default is 1. */
  step?: number;
  /** Reset value on double-click (if defined). */
  onReset?: number;
  /**
     Show a label displaying the value (default is true).
     In case a function is provided, it is used to reformat the value.
   */
  labelValue?: boolean | ((value: number) => string);
  className?: string;
  style?: React.CSSProperties;
  latency?: number;
}

const FORMAT_VALUE = (v: number): string => Number(v).toString();
const FORMAT_RANGE = (v: number): string => (v > 0 ? `+${v}` : `-${-v}`);
const FORMATING =
  (props: SliderFieldProps): (undefined | ((v: number) => string)) => {
    const { labelValue = true, min } = props;
    if (labelValue === false) return undefined;
    if (labelValue === true) return min < 0 ? FORMAT_RANGE : FORMAT_VALUE;
    return labelValue;
  };

const CSS_SLIDER = 'dome-text-label dome-xForm-units dome-xForm-slider-value';
const SHOW_SLIDER = `${CSS_SLIDER} dome-xForm-slider-show`;
const HIDE_SLIDER = `${CSS_SLIDER} dome-xForm-slider-hide`;

/**
   Slider Field
   @category Number Fields
 */
export function SliderField(props: SliderFieldProps): JSX.Element {
  const { min, max, step = 1, latency = 600, onReset } = props;
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const css = Utils.classes('dome-xForm-slider-field', props.className);
  const checked = useChecker(props.state, props.checker);
  const delayed = useLatency(checked, latency);
  const [label, setLabel] = React.useState<string | undefined>(undefined);
  const { value, error, onChanged } = delayed;
  const labeling = FORMATING(props);
  const onChange = React.useMemo(
    () => {
      const fadeOut = debounce(() => setLabel(undefined), latency);
      return (evt: InputEvent) => {
        const v = Number.parseInt(evt.target.value, 10);
        if (!Number.isNaN(v)) {
          onChanged(v, undefined);
          const vlabel = labeling && labeling(v);
          setLabel(vlabel);
          if (vlabel) fadeOut();
        } else {
          setLabel(undefined);
        }
      };
    }, [labeling, latency, onChanged, setLabel],
  );
  const onDoubleClick = React.useCallback(() => {
    if (onReset) {
      onChanged(onReset, undefined);
      setLabel(undefined);
    }
  }, [onReset, onChanged, setLabel]);
  const VALUELABEL = labeling && (
    <label className={label ? SHOW_SLIDER : HIDE_SLIDER}>
      {label}
    </label>
  );
  return (
    <Field
      {...props}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="range"
        value={value}
        min={min}
        max={max}
        step={step}
        className={css}
        style={props.style}
        disabled={disabled}
        onDoubleClick={onDoubleClick}
        onChange={onChange}
      />
      {VALUELABEL}
    </Field>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Date Field                                                         ---*/
/* --------------------------------------------------------------------------*/

/** @category Time and Date Fields */
export interface TimeOrDateFieldProps extends FieldProps<string | undefined> {
  min?: string;
  max?: string;
  className?: string;
  style?: React.CSSProperties;
  latency?: number;
}

/**
   Field with a Date Input element.

   The date is presented in english locale, with format `mm/dd/yyyy`,
   but the state value is a string compatible with
   javascript `Date('yyyy-dd-mm')` format.

   @category Time and Date Fields
 */
export function DateField(props: TimeOrDateFieldProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const css = Utils.classes('dome-xForm-date-field', props.className);
  const [value, error, onChange] = useTextInputField(props, 600);
  return (
    <Field
      {...props}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="date"
        value={value}
        min={props.min}
        max={props.max}
        className={css}
        style={props.style}
        disabled={disabled}
        onChange={onChange}
      />
    </Field>
  );
}

/**
   Field with a Time Input element.

   The time is presented in english locale, but its internal
   value is a string 'hh:mm' on 24h per day basis. This internal
   format can be used to form a valid javascript
   `Date('yyyy-mm-ddThh:mm')` object.

   @category Time and Date Fields
 */
export function TimeField(props: TimeOrDateFieldProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const css = Utils.classes('dome-xForm-date-field', props.className);
  const [value, error, onChange] = useTextInputField(props, 600);
  return (
    <Field
      {...props}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="time"
        value={value}
        min={props.min}
        max={props.max}
        className={css}
        style={props.style}
        disabled={disabled}
        onChange={onChange}
      />
    </Field>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Color Field                                                        ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export type ColorFieldProps = FieldProps<string | undefined>;

/** @category Form Fields */
export function ColorField(props: ColorFieldProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const [value, error, onChange] = useTextInputField(props, 600);
  return (
    <Field
      {...props}
      htmlFor={id}
      error={error}
    >
      <input
        id={id}
        type="color"
        value={value || '#ffffff'}
        className="dome-xForm-color-field"
        disabled={disabled}
        onChange={onChange}
      />
    </Field>
  );
}

/* --------------------------------------------------------------------------*/
/* --- Check Box Field                                                    ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export interface CheckboxFieldProps extends FieldProps<boolean> {
  /** Default is false */
  inverted?: boolean;
}

/** @category Form Fields */
export function CheckboxField(props: CheckboxFieldProps): JSX.Element | null {
  const { hidden, disabled } = useContext(props);

  if (hidden) return null;

  const { value, onChanged } = props.state;
  const { label, title, inverted } = props;
  const css = Utils.classes(
    'dome-xForm-field dome-text-label',
    disabled && 'dome-disabled',
  );
  const onChange = (): void => {
    onChanged(!value, undefined);
  };
  return (
    <Checkbox
      className={css}
      label={label}
      title={title}
      disabled={disabled}
      value={inverted ? !value : value}
      onChange={onChange}
    />
  );
}

/* --------------------------------------------------------------------------*/
/* --- Radio Box Field                                                    ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export interface RadioFieldProps<A> extends FieldProps<A> {
  value: A;
}

/** @category Form Fields */
export function RadioField<A>(props: RadioFieldProps<A>): JSX.Element | null {
  const { hidden, disabled } = useContext(props);

  if (hidden) return null;

  const { value: selection, onChanged } = props.state;
  const onSelection = (value: A): void => onChanged(value, undefined);
  const { label, title, value } = props;
  const css = Utils.classes(
    'dome-xForm-field dome-text-label',
    disabled && 'dome-disabled',
  );

  return (
    <Radio
      className={css}
      label={label}
      title={title}
      value={value}
      disabled={disabled}
      selection={selection}
      onSelection={onSelection}
    />
  );
}

/* --------------------------------------------------------------------------*/
/* --- Select Menu Field                                                  ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export interface SelectFieldProps extends FieldProps<string | undefined> {
  placeholder?: string;
  children?: React.ReactNode;
}

/**
   Children must be standard `<option>` or `<optgroup>` elements.

   @category Form Fields
 */
export function SelectField(props: SelectFieldProps): JSX.Element {
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const { value, error, onChanged } = useChecker(props.state, props.checker);
  const onChange =
    (newValue: string | undefined): void => onChanged(newValue, undefined);
  const { children, placeholder } = props;
  return (
    <Field
      {...props}
      offset={5}
      error={error}
      htmlFor={id}
    >
      <SelectMenu
        id={id}
        value={value}
        disabled={disabled}
        placeholder={placeholder}
        onChange={onChange}
      >
        {children}
      </SelectMenu>
    </Field>
  );
}

/** @category Form Fields */
export interface MenuFieldOption<A> {
  value: A;
  label: string;
}

/** @category Form Fields */
export interface MenuFieldProps<A> extends FieldProps<A> {
  /** Field label. */
  label: string;
  /** Field tooltip text. */
  title?: string;
  /** Field state. */
  state: FieldState<A>;
  placeholder?: string;
  defaultValue: A;
  options: MenuFieldOption<A>[];
}

type ENTRY<A> = { option: JSX.Element, field: string, value: A };

/**
   Creates a `<SelectField/>` form field with a predefine set
   of (typed) options.

   @category Form Fields
 */
export function MenuField<A>(props: MenuFieldProps<A>): JSX.Element {
  const entries: ENTRY<A>[] = React.useMemo(() =>
    props.options.map((e, k) => {
      const field = `item#${k}`;
      const option = <option value={field} key={field} label={e.label} />;
      return { field, option, value: e.value };
    }), [props.options]);
  const input = React.useCallback(
    (v) => entries.find((e) => e.value === v)?.field
    , [entries]
  );
  const output = React.useCallback(
    (f) => entries.find((e) => e.field === f)?.value ?? props.defaultValue
    , [entries, props.defaultValue]
  );
  const defaultField = React.useMemo(
    () => input(props.defaultValue),
    [input, props.defaultValue]
  );
  const state = useFilter<A, string | undefined>(
    props.state,
    input, output,
    defaultField,
  );
  return (
    <SelectField
      state={state}
      label={props.label}
      title={props.title}
      placeholder={props.placeholder} >
      {entries.map((e) => e.option)}
    </SelectField>
  );
}


// --------------------------------------------------------------------------
