/* --------------------------------------------------------------------------*/
/* --- Form Fields                                                        ---*/
/* --------------------------------------------------------------------------*/

/**
   @packageDocumentation
   @module dome/layout/form
 */

import { debounce } from 'lodash';
import React from 'react';
import * as Dome from 'dome';
import * as Utils from 'dome/misc/utils';
import { SVG } from 'dome/controls/icons';

export type Error =
  | undefined | boolean | string
  | { [key: string]: Error } | Error[];
export type Checker<A> = (value: A) => boolean | Error;
export type Callback<A> = (value: A, error: Error) => void;
export type FieldState<A> = [A, Error, Callback<A>];

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
): Error {
  if (checker) {
    try {
      const r = checker(value);
      if (r === undefined || r === true) return undefined;
      return r;
    } catch (err) {
      return err.toString() || false;
    }
  }
  return undefined;
}

export function isValid(err: Error): boolean { return !err; }

type ObjectError = { [key: string]: Error };

function isObjectError(err: Error): err is ObjectError {
  return typeof err === 'object' && !Array.isArray(err);
}

function isArrayError(err: Error): err is Error[] {
  return Array.isArray(err);
}

function isValidObject(err: ObjectError): boolean {
  const ks = Object.keys(err);
  for (let k = 0; k < ks.length; k++) {
    if (!isValid(err[ks[k]])) return false;
  }
  return true;
}

function isValidArray(err: Error[]): boolean {
  for (let k = 0; k < err.length; k++) {
    if (!isValid(err[k])) return false;
  }
  return true;
}

/* --------------------------------------------------------------------------*/
/* --- State Hooks                                                        ---*/
/* --------------------------------------------------------------------------*/

export function useState<A>(
  defaultValue: A,
  checker?: Checker<A>,
  onChange?: Callback<A>,
): FieldState<A> {
  const [value, setValue] = React.useState<A>(defaultValue);
  const [error, setError] = React.useState<Error>(undefined);
  const setState = React.useCallback((newValue: A, newError: Error) => {
    const localError = validate(newValue, checker) || newError;
    setValue(newValue);
    setError(localError);
    if (onChange) onChange(newValue, localError);
  }, [checker, setValue, setError, onChange]);
  return [value, error, setState];
}

export function useDefault<A>(
  state: FieldState<A | undefined>,
  defaultValue: A,
): FieldState<A> {
  const [value, error, setState] = state;
  return [value ?? defaultValue, error, setState];
}

export function useRequired<A>(
  state: FieldState<A>,
): FieldState<A | undefined> {
  const [value, error, setState] = state;
  const cache = React.useRef(value);
  const update = React.useCallback(
    (newValue: A | undefined, newError: Error) => {
      if (newValue === undefined) {
        setState(cache.current, newError || 'Required field');
      } else {
        setState(newValue, newError);
      }
    }, [cache, setState],
  );
  return [value, error, update];
}

export function useChecker<A>(
  state: FieldState<A>,
  checker?: Checker<A>,
): FieldState<A> {
  const [value, error, setState] = state;
  const update = React.useCallback((newValue: A, newError: Error) => {
    const localError = validate(newValue, checker) || newError;
    setState(newValue, localError);
  }, [checker, setState]);
  return [value, error, update];
}

export function useFilter<A, B>(
  state: FieldState<A>,
  input: (value: A) => B,
  output: (value: B) => A,
  defaultValue: B,
): FieldState<B> {
  const [value, error, setState] = state;
  const cacheA = React.useRef<A>(value);
  const cacheB = React.useRef<B>(defaultValue);
  const update = React.useCallback(
    (newValue: B, newError: Error) => {
      try {
        const outValue = output(newValue);
        setState(outValue, newError);
      } catch (outErr) {
        const outError = newError || outErr.toString() || 'Invalid value';
        setState(cacheA.current, outError);
      }
    }, [cacheA, output, setState],
  );
  cacheA.current = value;
  try {
    const inValue = input(value);
    cacheB.current = inValue;
    return [inValue, error, update];
  } catch (inErr) {
    const inError = error || inErr.toString() || 'Invalid value';
    return [cacheB.current, inError, update];
  }
}

export function useProperty<A, K extends keyof A>(
  state: FieldState<A>,
  property: K,
  checker?: Checker<A[K]>,
): FieldState<A[K]> {
  const [value, error, setState] = state;
  const update = React.useCallback((newProp: A[K], newError: Error) => {
    const newValue = { ...value, [property]: newProp };
    const objError = isObjectError(error) ? error : {};
    const propError = validate(newProp, checker) || newError;
    const localError = { ...objError, [property]: propError };
    setState(newValue, isValidObject(localError) ? undefined : localError);
  }, [value, error, setState, property, checker]);
  return [value[property], error, update];
}

export function useLatency<A>(
  state: FieldState<A>,
  latency?: number,
): FieldState<A> {
  const [initValue, initError, setState] = state;
  const period = latency ?? 0;
  const [value, setValue] = React.useState(initValue);
  const [error, setError] = React.useState(initError);
  const propagate = React.useMemo(
    () => (period > 0 ? debounce(setState, period) : setState),
    [period, setState],
  );
  const update = React.useCallback((newValue, newError) => {
    setValue(newValue);
    setError(newError);
    propagate(newValue, newError);
  }, [setValue, setError, propagate]);
  return [value, error, update];
}

export function useIndex<A>(
  state: FieldState<A[]>,
  index: number,
  checker?: Checker<A>,
): FieldState<A> {
  const [array, error, setState] = state;
  const update = React.useCallback((newValue: A, newError: Error) => {
    const newArray = array.slice();
    newArray[index] = newValue;
    const localError = isArrayError(error) ? error.slice() : [];
    const valueError = validate(newValue, checker) || newError;
    localError[index] = valueError;
    setState(newArray, isValidArray(localError) ? undefined : localError);
  }, [array, error, setState, index, checker]);
  const itemError = isArrayError(error) ? error[index] : undefined;
  return [array[index], itemError, update];
}

/* --------------------------------------------------------------------------*/
/* --- Basics                                                             ---*/
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

export interface Children { children: React.ReactNode }

/* --------------------------------------------------------------------------*/
/* --- Form Context                                                       ---*/
/* --------------------------------------------------------------------------*/

interface FormContext {
  disabled: boolean;
  hidden: boolean;
}

const CONTEXT = React.createContext<FormContext | undefined>(undefined);

const HIDDEN =
  ({ hidden = false, visible = true }: FilterProps) => hidden || !visible;

const DISABLED =
  ({ disabled = false, enabled = true }: FilterProps) => disabled || !enabled;

function useContext(props?: FilterProps): FormContext {
  const Parent = React.useContext(CONTEXT);
  return {
    hidden: (props && HIDDEN(props)) || (Parent?.hidden ?? false),
    disabled: (props && DISABLED(props)) || (Parent?.disabled ?? false),
  };
}

/** @category Form Containers */
export function Filter(props: FilterProps & Children) {
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
export interface FormProps extends FilterProps, Children {
  /** Additional container class. */
  className?: string;
  /** Additional container style. */
  style?: React.CSSProperties;
}

/**
   Main Form Container.
   @category Form Containers
 */
export const Form = (props: FormProps) => {
  const { className, style, children, ...filter } = props;
  const { hidden, disabled } = useContext(filter);
  const css = Utils.classes('dome-xForm-grid', className);
  if (hidden) return null;
  return (
    <div className={css} style={style}>
      <CONTEXT.Provider value={{ hidden, disabled }}>
        {children}
      </CONTEXT.Provider>
    </div>
  );
};

// --------------------------------------------------------------------------
// --- Warning Badge
// --------------------------------------------------------------------------

export interface WarningProps {
  /** Short warning message (displayed on hover). */
  warning?: string;
  /** Error details (if a string is provided, in tooltip). */
  error?: Error;
  /** Label offset. */
  offset?: number;
}

/** Warning Badge. */
export function Warning(props: WarningProps) {
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
export function Block(props: FilterProps & Children) {
  const { children, ...filter } = props;
  return (
    <Filter {...filter}>
      <div className="dome-xForm-block">
        {children}
      </div>
    </Filter>
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
  error?: Error;
  /** Fold/Unfold settings. */
  settings?: string;
  /** Fold/Unfold state (defaults to false). */
  unfold?: boolean;
}

/** @category Form Fields */
export function Section(props: SectionProps) {
  const { label, title, children, warning, error, ...filter } = props;
  const { disabled, hidden } = useContext(filter);
  const [unfold, flip] = Dome.useFlipSettings(props.settings, props.unfold);

  if (hidden) return null;

  const hasWarning = unfold && !disabled && !error;

  const cssTitle = Utils.classes(
    'dome-text-title',
    disabled && 'dome-disabled',
  );

  return (
    <CONTEXT.Provider value={{ hidden, disabled }}>
      <div className="dome-xForm-section">
        <div className="dome-xForm-fold" onClick={flip}>
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
  error?: Error;
}

let FIELDID = 0;

/** Generates a unique, stable identifier. */
export function useHtmlFor() {
  return React.useMemo(() => `dome-field ${FIELDID++}`, []);
}

/**
   Generic Field.
   Layout its content in a top-left aligned box on the right of the label.
   @category Form Fields
 */
export function Field(props: GenericFieldProps) {
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
      <label
        className={cssLabel}
        style={{ top: offset }}
        htmlFor={htmlFor}
        title={title}
      >
        {label}
      </label>
      <div className={cssField}>
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

type InputEvent<A> = { target: { value: A } };
type InputState<A> = [string, Error, (evt: InputEvent<A>) => void];

function useChangeEvent<A>(setState: Callback<A>) {
  return React.useCallback(
    (evt: InputEvent<A>) => { setState(evt.target.value, undefined); },
    [setState],
  );
}

function useTextInputField(
  props: FieldTextProps,
  defaultLatency: number,
): InputState<string> {
  const checked = useChecker(props.state, props.checker);
  const period = props.latency ?? defaultLatency;
  const [value, error, setState] = useLatency(checked, period);
  const onChange = useChangeEvent(setState);
  return [value || '', error, onChange];
}

/* --------------------------------------------------------------------------*/
/* --- Text Fields                                                        ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export interface FieldTextProps extends FieldProps<string | undefined> {
  placeholder?: string;
  className?: string;
  style?: React.CSSProperties;
  latency?: number;
}

/**
   Text Field.
   @category Form Fields
 */
export const FieldText = (props: FieldTextProps) => {
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
};

/**
   Monospaced Text Field.
   @category Form Fields
 */
export const FieldCode = (props: FieldTextProps) => {
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
};

/* --------------------------------------------------------------------------*/
/* --- Text Area Fields                                                   ---*/
/* --------------------------------------------------------------------------*/

/** @category Form Fields */
export interface FieldTextAreaProps extends FieldTextProps {
  /** Number of columns (default 35, min 5). */
  cols?: number;
  /** Number of rows (default 5, min 2). */
  rows?: number;
}

/**
   Text Field Area.
   @category Form Fields
 */
export const FieldTextArea = (props: FieldTextAreaProps) => {
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
};

/**
   Monospaced Text Field Area.
   @category Form Fields
 */
export const FieldCodeArea = (props: FieldTextAreaProps) => {
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
};

/* --------------------------------------------------------------------------*/
/* --- Number Field                                                       ---*/
/* --------------------------------------------------------------------------*/

export interface FieldNumberProps extends FieldProps<number | undefined> {
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

function NUMBER_OF_TEXT(s: string): number | undefined {
  if (s === '') return undefined;
  const n = Number.parseFloat(s.replace(/[ ,]/g, ''));
  if (Number.isNaN(n)) throw new Error('Invalid number');
  return n;
}

/**
   Text Field.
   @category Form Fields
 */
export const FieldNumber = (props: FieldNumberProps) => {
  const { units, latency = 600 } = props;
  const { disabled } = useContext(props);
  const id = useHtmlFor();
  const css = Utils.classes('dome-xForm-number-field', props.className);
  const checked = useChecker(props.state, props.checker);
  const filtered = useFilter(checked, TEXT_OF_NUMBER, NUMBER_OF_TEXT, '');
  const [value, error, setState] = useLatency(filtered, latency);
  const onChange = useChangeEvent(setState);
  const UNITS = units && (
    <label className="dome-text-label dome-xForm-units">{units}</label>
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
      {UNITS}
    </Field>
  );
};

// --------------------------------------------------------------------------
