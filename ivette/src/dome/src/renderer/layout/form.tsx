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

type ObjectError = { [key: string]: Error }

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
    const localError = validate(value, checker) || newError;
    setValue(newValue);
    setError(localError);
    if (onChange) onChange(newValue, localError);
  }, [setValue, setError, onChange]);
  return [value, error, setState];
}

export function useChecker<A>(
  state: FieldState<A>,
  checker?: Checker<A>,
): FieldState<A> {
  const [value, error, setState] = state;
  const update = React.useCallback((newValue: A, newError: Error) => {
    const localError = validate(newValue, checker) || newError;
    setState(newValue, localError);
  }, [setState]);
  return [value, error, update];
}

export function useProperty<A, K extends keyof A>(
  state: FieldState<A>,
  property: K,
  checker?: Checker<A[K]>,
  onError?: string,
): FieldState<A[K]> {
  const [value, error, setState] = state;
  const update = React.useCallback((newProp: A[K], newError: Error) => {
    const newValue = { ...value, [property]: newProp };
    const objError = isObjectError(error) ? error : {};
    const propError = validate(newProp, checker) || newError;
    const localError = { ...objError, [property]: propError };
    setState(newValue, isValidObject(localError) ? undefined : localError);
  }, [value, error, setState, property, checker, onError]);
  return [value[property], error, update];
}

export function useLatency<A>(
  state: FieldState<A>,
  latency?: number,
): FieldState<A> {
  const [initValue, initError, setState] = state;
  const period = Math.max(latency ?? 0, 0);
  const [value, setValue] = React.useState(initValue);
  const [error, setError] = React.useState(initError);
  const propagate = React.useCallback(
    debounce(setState, period),
    [latency, setState],
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
  onError?: string,
): FieldState<A> {
  const [array, error, setState] = state;
  const update = React.useCallback((newValue: A, newError: Error) => {
    const newArray = array.slice();
    newArray[index] = newValue;
    const localError = isArrayError(error) ? error.slice() : [];
    const valueError = validate(newValue, checker) || newError;
    localError[index] = valueError;
    setState(newArray, isValidArray(localError) ? undefined : localError);
  }, [array, error, setState, index, checker, onError]);
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
   Layout its contents inside a full-width block.
   The children are _not_ supposed to contain `<Field />` like elements,
   only custom controls that fits a full-width containter.
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

/** Form Section. */
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
/* --- Value Filter                                                      --- */
/* --------------------------------------------------------------------------*/

export interface FieldProps extends FilterProps, Children {
  /** Field label. */
  label: string;
  /** Field tooltip text. */
  title?: string;
  /** Field offset. */
  offset?: number;
  /** Html tag `<input />` element. */
  htmlFor?: string;
}

let FIELDID = 0;

export function useHtmlFor() {
  return React.useMemo(() => `dome-field ${FIELDID++}`, []);
}

/**
   Generic Field.
   Layout its content in a top-left aligned box on the right of the label.
 */
export function Field(props: FieldProps) {
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
      </div>
    </>
  );

}

// --------------------------------------------------------------------------
