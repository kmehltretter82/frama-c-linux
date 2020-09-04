// --------------------------------------------------------------------------
// --- Forms Layout
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/layout/form
 */

import { debounce } from 'lodash';
import React from 'react';
import { SVG } from 'dome/controls/icons';
import * as Utils from 'dome/misc/utils';

export type Error = undefined | string;
export type Setter<A> = (value: A) => void;
export type Checker<A> = (value: A) => boolean | Error;
export type State<A> = [A, Setter<A>]
export type Callback<A> = (value: A, valid: boolean) => void;

/* --------------------------------------------------------------------------*/
/* --- State Utilities                                                    ---*/
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
  message: undefined | string,
): Error {
  if (checker) {
    try {
      const r = checker(value);
      if (r === undefined || r === true) return undefined;
      return message || r || 'Invalid Field';
    } catch (err) {
      return err.toString();
    }
  }
  return undefined;
}

export function isValid(err: Error): boolean { return !err; }

export function useCallback<A>(
  value: A,
  error: Error,
  onChange?: Callback<A>,
) {
  React.useEffect(
    () => { if (onChange) onChange(value, isValid(error)); },
    [value, error, onChange],
  );
}

export function useProperty<A, K extends keyof A>(
  state: State<A>,
  property: K,
): State<A[K]> {
  const [value, setValue] = state;
  const update = React.useCallback((newProp: A[K]) => {
    const newValue = { ...value, [property]: newProp };
    setValue(newValue);
  }, [value, property, setValue]);
  return [value[property], update];
}

export function useIndex<A>(
  state: State<A[]>,
  index: number,
): State<A> {
  const [array, setValue] = state;
  const update = React.useCallback((newItem: A) => {
    const newArray = array.slice();
    newArray[index] = newItem;
    setValue(newArray);
  }, [array, index, setValue]);
  return [array[index], update];
}

/* --------------------------------------------------------------------------*/
/* --- Form Context                                                       ---*/
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

interface FormContext {
  disabled: boolean;
  hidden: boolean;
}

const CONTEXT = React.createContext<FormContext | undefined>(undefined);

const HIDDEN =
  ({ hidden = false, visible = true }: FilterProps) => hidden || !visible;

const DISABLED =
  ({ disabled = false, enabled = true }: FilterProps) => disabled || !enabled;

function useContext(props: FilterProps): FormContext {
  const Parent = React.useContext(CONTEXT);
  return {
    hidden: HIDDEN(props) || (Parent?.hidden ?? false),
    disabled: DISABLED(props) || (Parent?.disabled ?? false),
  }
}

export interface Children { children: React.ReactNode; }

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
/* --- Value Filter                                                      --- */
/* --------------------------------------------------------------------------*/

export interface FieldProps<A> {
  state: State<A>;
  checker?: Checker<A>;
  message?: string;
  onChange?: Callback<A>;
  latency?: number;
}

type FilterState<A> = [A, Setter<A>, Error];

export function useField<A>(props: FieldProps<A>): FilterState<A> {
  const { checker, message, latency = 0, onChange } = props;
  const [value, setValue] = props.state;
  const [current, setCurrent] = React.useState<A>(value);
  const [error, setError] = React.useState<Error>(undefined);
  const update = React.useMemo(() => {
    if (!latency)
      return (newValue: A) => {
        const newError = validate(newValue, checker, message);
        setCurrent(newValue);
        setValue(newValue);
        setError(newError);
        if (onChange) onChange(newValue, isValid(newError));
      };
    const propagate = debounce((newValue) => {
      const newError = validate(newValue, checker, message);
      setValue(newValue);
      setError(newError);
      if (onChange) onChange(newValue, isValid(newError));
    });
    return (newValue: A) => {
      setCurrent(newValue);
      propagate(newValue);
    }
  }, [checker, message, latency, onChange, setValue, setError]);
  return [current, update, error];
};

// --------------------------------------------------------------------------
// --- Form Container
// --------------------------------------------------------------------------

export interface FormProps extends FilterProps, Children {
  /** Additional container class. */
  className?: string;
  /** Additional container style. */
  style?: React.CSSProperties;
}

/** Form Container. */
export const Form = (props: FormProps) => {
  const { className, style, children, ...filter } = props;
  const css = Utils.classes('dome-xForm-grid', className);
  return (
    <div className={css} style={style}>
      <Filter {...filter}>
        {children}
      </Filter>
    </div>
  );
}

export interface WarningProps {
  /** Short warn message in case of error. */
  warn?: string;
  /** Error description (in tooltip if warn, on hover otherwized). */
  error?: Error;
  /** Label offset. */
  offset?: number;
}

/** Warning badge */
export function Warning(props: WarningProps) {
  const { error, warn, offset = 0 } = props;
  if (!error) return null;
  const hovered = warn ? warn : error;
  const tooltip = warn ? error : undefined;
  const style = warn ? { width: 'max-content' } : undefined;

  return (
    <div
      className="dome-xIcon dome-xForm-error"
      style={{ top: offset - 2 }} >
      <SVG id="WARNING" size={11} title={tooltip} />
      <span
        className="dome-xForm-warning"
        style={style}>
        {hovered}
      </span>
    </div>
  );
};

// --------------------------------------------------------------------------
