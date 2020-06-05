// --------------------------------------------------------------------------
// --- Buttons, Check Boxes and Radio Groups
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/controls/buttons
*/

import React from 'react';
import { Icon } from './icons';
import { LabelProps } from './labels';
import './style.css';

const DISABLED = ({ disabled = false, enabled = true }) => !!disabled || !enabled;

interface EVENT {
  stopPropagation: () => void;
}

const TRIGGER = (onClick?: () => void) => (evt?: EVENT) => {
  evt && evt.stopPropagation();
  if (onClick) onClick();
};

// --------------------------------------------------------------------------
// --- LCD
// --------------------------------------------------------------------------

const LCDCLASS = 'dome-xButton dome-xBoxButton dome-text-code dome-xButton-lcd ';

/** Button-like label. */
export function LCD(props: LabelProps) {
  return (
    <label
      className={LCDCLASS + (props.className || '')}
      title={props.title}
      style={props.style}
    >
      {props.icon && <Icon id={props.icon} />}
      {props.label}
      {props.children}
    </label>
  );
};

// --------------------------------------------------------------------------
// --- Led
// --------------------------------------------------------------------------

export type LEDstatus =
  undefined | 'inactive' | 'active' | 'positive' | 'negative' | 'warning';

export interface LEDprops {
  /**
  Led status:
     - `'inactive'`: off (default)
     - `'active'`: blue color
     - `'positive'`: green color
     - `'negative'`: red color
     - `'warning'`: orange color
   */
  status?: LEDstatus;
  /** Blinking Led (default: `false`). */
  blink?: boolean;
  /** Tooltip text. */
  title?: string;
  /** Additional CSS class. */
  className?: string;
  /** Additional CSS style. */
  style?: React.CSSProperties;
}

export const LED = (props: LEDprops) => {
  const classes = 'dome-xButton-led dome-xButton-led-'
    + (props.status || 'inactive')
    + (props.blink ? ' dome-xButton-blink' : '')
    + (props.className ? ' ' + props.className : '');
  return (<div className={classes} title={props.title} style={props.style} />);
};

// --------------------------------------------------------------------------
// --- Button
// --------------------------------------------------------------------------

const VISIBLE: React.CSSProperties = { visibility: 'visible' };
const HIDDEN: React.CSSProperties = { visibility: 'hidden' };

interface LABELprops {
  disabled: boolean;
  label: string;
};

const LABEL = ({ disabled, label }: LABELprops) => (
  <div className="dome-xButton-label" >
    <div className="dome-xButton-label dome-control-enabled"
      style={disabled ? HIDDEN : VISIBLE} >{label}</div>
    <div className="dome-xButton-label dome-control-disabled"
      style={disabled ? VISIBLE : HIDDEN}>{label}</div>
  </div>
);

export type ButtonKind =
  undefined | 'default' | 'active' | 'primary' | 'warning' | 'positive' | 'negative';

export interface ButtonProps {
  /** Text of the label. Prepend to other children elements. */
  label?: string;
  /** Icon identifier. Displayed on the left side of the label. */
  icon?: string;
  /** Tool-tip description. */
  title?: string;
  /** Additional class. */
  className?: string;
  /** Additional style. */
  style?: React.CSSProperties;
  /** Defaults to `false`. */
  selected?: boolean;
  /** Defaults to `true`. */
  enabled?: boolean;
  /** Defaults to `false`. */
  disabled?: boolean;
  /** Defaults to `true`. */
  visible?: boolean;
  /** Defaults to `true`. */
  display?: boolean;
  /**
     May gain focus.
     Focused button can be clicked with the `ENTER` key.
     Defaults to `false`.
   */
  focusable?: boolean;
  /** Styled bytton:
     - `'default'`: normal button;
     - `'active'`: active normal button;
     - `'primary'`: primary button, in blue;
     - `'warning'`: warning button, in orange;
     - `'positive'`: positive button, in green;
     - `'negative'`: negative button, in red.
   */
  kind?: ButtonKind;
  /** Blinking button. Defaults to `false`. */
  blink?: boolean;
  /**
     Button callback.
     An undefined callback automatically disables the button.
   */
  onClick?: () => void;
}

/** Standard button. */
export function Button(props: ButtonProps) {
  const disabled = props.onClick ? DISABLED(props) : true;
  const { focusable = false, kind = 'default',
    visible = true, display = true, blink = false,
    selected, icon, label, className = '' } = props;
  const theClass = 'dome-xButton dome-xBoxButton dome-xButton-'
    + (selected ? 'selected' : kind)
    + (!blink ? '' : ' dome-xButton-blink')
    + (visible ? '' : ' dome-control-hidden')
    + (display ? '' : ' dome-control-erased')
    + (className ? ' ' + className : '');
  const nofocus = focusable ? undefined : true;
  console.log('ICON', Icon);
  console.log('LABEL', LABEL);
  return (
    <button type='button'
      className={theClass}
      disabled={disabled}
      onClick={TRIGGER(props.onClick)}
      title={props.title}
      style={props.style}
      tabIndex={nofocus && -1}
      onMouseDown={nofocus && ((evt) => evt.preventDefault())}
    >
      {icon && <Icon id={icon} />}
      {label && <LABEL disabled={disabled} label={label} />}
    </button>
  );
};

// --------------------------------------------------------------------------
// --- Icon Button
// --------------------------------------------------------------------------

/** Circled Icon Button. The label property is ignored. */
export const CircButton = (props: ButtonProps) => {
  const disabled = props.onClick ? DISABLED(props) : true;
  const { focusable = false, kind = 'default',
    visible = true, display = true,
    selected, icon, blink, className = '' } = props;
  const theClass = 'dome-xButton dome-xCircButton dome-xButton-'
    + (selected ? 'selected' : kind)
    + (!blink ? '' : ' dome-xButton-blink')
    + (visible ? '' : ' dome-control-hidden')
    + (display ? '' : ' dome-control-erased')
    + (className ? ' ' + className : '');
  const nofocus = focusable ? undefined : true;
  return (
    <button type='button'
      className={theClass}
      disabled={disabled}
      onClick={TRIGGER(props.onClick)}
      title={props.title}
      style={props.style}
      tabIndex={nofocus && -1}
      onMouseDown={nofocus && ((evt) => evt.preventDefault())}
    >
      {icon && <Icon offset={-1} id={icon} />}
    </button>
  );
};

// --------------------------------------------------------------------------
// --- Icon Button
// --------------------------------------------------------------------------

export type IconButtonKind =
  undefined | 'default' | 'negative' | 'positive' | 'warning';

export interface IconButtonProps {
  /** Icon identifier. Displayed on the left side of the label. */
  icon: string;
  /** Tool-tip description. */
  title?: string;
  /** Icon size, in pixels (default: `12`). */
  size?: number;
  /** Vertical offset, in pixels. */
  offset?: number;
  /** Additional class. */
  className?: string;
  /** Additional style. */
  style?: React.CSSProperties;
  /** Defaults to `false`. */
  selected?: boolean;
  /** Defaults to `true`. */
  enabled?: boolean;
  /** Defaults to `false`. */
  disabled?: boolean;
  /** Defaults to `true`. */
  visible?: boolean;
  /** Defaults to `true`. */
  display?: boolean;
  /** Styled bytton:
     - `'default'`: normal button;
     - `'warning'`: warning button, in orange;
     - `'positive'`: positive button, in green;
     - `'negative'`: negative button, in red.
   */
  kind?: IconButtonKind;
  /**
     Button callback.
     An undefined callback automatically disables the button.
   */
  onClick?: () => void;
}

/** Borderless Icon Button. Label property is ignored. */
export function IconButton(props: IconButtonProps) {
  const disabled = props.onClick ? DISABLED(props) : true;
  const {
    icon, title, className,
    visible = true, display = true, selected,
    kind = 'default'
  } = props;
  if (!icon) return null;
  const theClass = 'dome-xIconButton'
    + ' dome-xIconButton-' + (selected ? 'selected' : kind)
    + (disabled ? ' dome-control-disabled' : ' dome-control-enabled')
    + (visible ? '' : ' dome-control-hidden')
    + (display ? '' : ' dome-control-erased')
    + (className ? ' ' + className : '');
  return (
    <Icon
      id={icon}
      title={title}
      size={props.size}
      offset={props.offset}
      style={props.style}
      className={theClass}
      onClick={TRIGGER(disabled ? undefined : props.onClick)}
    />
  );
};

// --------------------------------------------------------------------------
// --- CheckBox
// --------------------------------------------------------------------------

const CHECKBOX_ENABLED = 'dome-control-enabled dome-xCheckbox ';
const CHECKBOX_DISABLED = 'dome-control-disabled dome-xCheckbox ';

export interface CheckProps {
  /** Button label. */
  label: string;
  /** Button tooltip. */
  title?: string;
  /** Additional class. */
  className?: string;
  /** Additional style. */
  style?: React.CSSProperties;
  /** Defaults to `true`. */
  enabled?: boolean;
  /** Defaults to `false`. */
  disabled?: boolean;
  /** Defaults to `false`. */
  value?: boolean;
  /** Callback to changes. */
  onChange?: (newValue: boolean) => void;
}

/** Checkbox button. */
export const Checkbox = (props: CheckProps) => {
  const { value, onChange } = props;
  const disabled = onChange ? DISABLED(props) : true;
  const callback = onChange && (() => onChange(!value));
  const baseClass = disabled ? CHECKBOX_DISABLED : CHECKBOX_ENABLED;
  const labelClass = props.className || '';
  return (
    <label
      title={props.title}
      style={props.style}
      className={baseClass + labelClass} >
      <input type="checkbox"
        disabled={disabled}
        checked={value}
        onChange={callback} />
      {props.label}
    </label>
  );
};

/** Switch button. */
export const Switch = (props: CheckProps) => {
  const { onChange, value } = props;
  const disabled = onChange ? DISABLED(props) : true;
  const iconId = props.value ? 'SWITCH.ON' : 'SWITCH.OFF';
  const onClick = onChange && (() => onChange(!value));
  const className = 'dome-xSwitch '
    + (disabled ? 'dome-control-disabled' : 'dome-control-enabled')
    + (props.className ? ' ' + props.className : '');
  return (
    <label
      title={props.title}
      style={props.style}
      className={className}
      onClick={TRIGGER(onClick)}
    >
      <Icon size={16} id={iconId} />
      {props.label}
    </label>
  );
};

// --------------------------------------------------------------------------
// --- Radio Button
// --------------------------------------------------------------------------

export interface RadioProps<A> {
  /** Button label. */
  label: string;
  /** Button tooltip. */
  title?: string;
  /** Additional class. */
  className?: string;
  /** Additional style. */
  style?: React.CSSProperties;
  /** Defaults to `true`. */
  enabled?: boolean;
  /** Defaults to `false`. */
  disabled?: boolean;
  /** Value associated to the Radio. */
  value: A;
  /** Currently selected value. */
  selection?: A;
  /** Callback to changes. */
  onSelection?: (newValue: A) => void;
}

/** Radio Button. See also [[RadioGroup]]. */
export function Radio<A>(props: RadioProps<A>) {
  const { onSelection, value, selection } = props;
  const disabled = onSelection ? DISABLED(props) : true;
  const checked = value === selection;
  const onChange = onSelection && (() => onSelection(value));
  const baseClass = disabled ? CHECKBOX_DISABLED : CHECKBOX_ENABLED;
  const labelClass = props.className || '';
  return (
    <label
      title={props.title}
      style={props.style}
      className={baseClass + labelClass} >
      <input type="radio"
        disabled={disabled} checked={checked} onChange={onChange} />
      {props.label}
    </label>
  );
};

// --------------------------------------------------------------------------
// --- Radio Group
// --------------------------------------------------------------------------

export interface RadioGroupProps<A> {
  /** Defaults to `true`. */
  enabled?: boolean;
  /** Defaults to `false`. */
  disabled?: boolean;
  /** Currently selected value. */
  value?: A;
  /** Callback to selected values. */
  onChange?: (newValue: A) => void;
  /** Default selected value. */
  className?: string;
  /** Additional style for the `<dov/>` container of Raiods */
  style?: React.CSSProperties;
  /** [[Radio]] Buttons. */
  children: any;
};

/**
   Selector of Radio Buttons.
   Childrens of the `RadioGroup` shall be [[Radio]] buttons.

   The selected value of the group is broadcasted to the radio buttons. Their
   callbacks are activated _before_ the radio group one, if any.

   If the radio group is disabled, all the radio buttons are disabled also and
   their `disabled` properties are ignored. On the contrary, when the radio
   group is enabled, the `disabled` property of each radio button is taken into
   account.

   The radio buttons inside a group are laidout in a vertical box with the additional
   styling properties.
 */
export function RadioGroup<A>(props: RadioGroupProps<A>) {
  const { className = '', style, value: selection, onChange: onGroupSelect } = props;
  const disabledGroup = onGroupSelect ? DISABLED(props) : true;
  const makeRadio = (elt: any) => {
    const radioProps = elt.props as RadioProps<A>;
    const disabled = disabledGroup || DISABLED(radioProps);
    const { onSelection: onRadioSelect } = radioProps;
    const onSelection = (v: A) => {
      onRadioSelect && onRadioSelect(v);
      onGroupSelect && onGroupSelect(v);
    };
    return React.cloneElement(elt, {
      disabled, enabled: !disabled, selection, onSelection
    });
  };
  return (
    <div className={'dome-xRadio-group ' + className} style={style}>
      {React.Children.map(props.children, makeRadio)}
    </div>
  );
}

// --------------------------------------------------------------------------
// --- Selector
// --------------------------------------------------------------------------

export interface SelectProps {
  /** Field identifier (to make forms or labels) */
  id?: string;
  /** Button tooltip */
  title?: string;
  /** Button placeholder */
  placeholder?: string;
  /** Defaults to `true`. */
  enabled?: boolean;
  /** Defaults to `false`. */
  disabled?: boolean;
  /** Currently selected value. */
  value?: string;
  /** Callback to selected values. */
  onChange?: (newValue?: string) => void;
  /** Default selected value. */
  className?: string;
  /** Additional style for the `<dov/>` container of Raiods */
  style?: React.CSSProperties;
  /** Shall be [[Item]] elements. */
  children: any;
}

/**
   Menu Button.

   The different options shall be specified with HTML `<option/>` and `<optgroup />` elements.
   Options and group shall be specified as follows:

       <optgroup label='…'>…</optgroup>
       <option value='…' disabled=… >…</option>

   **Warning:** most non-positionning CSS properties might not work on the`<select>` element due
   to the native rendering used by Chrome.
   You might use`-webkit-appearance: none` to cancel this behavior, you will have to restyle the
   component entirely, which is quite ugly by default.
 */
export function Select(props: SelectProps) {
  const { onChange, className = '', placeholder } = props;
  const disabled = onChange ? DISABLED(props) : true;
  const callback = (evt: React.ChangeEvent<HTMLSelectElement>) => {
    onChange && onChange(evt.target.value);
  };
  return (
    <select
      id={props.id}
      disabled={disabled}
      className={'dome-xSelect ' + className}
      style={props.style}
      title={props.title}
      value={props.value}
      onChange={callback}
    >
      {placeholder && <option value=''>— {placeholder} —</option>}
      {props.children}
    </select>
  );
}

// --------------------------------------------------------------------------
// --- Text Input
// --------------------------------------------------------------------------

export interface FieldProps {
  /** Field identifier (to make forms or labels) */
  id?: string;
  /** Button tooltip */
  title?: string;
  /** Button placeholder */
  placeholder?: string;
  /** Defaults to `true`. */
  enabled?: boolean;
  /** Defaults to `false`. */
  disabled?: boolean;
  /** Default fo `false`. */
  autoFocus?: boolean;
  /** Currently selected value (updated on `ENTER` key)*/
  value?: string;
  /** Callback on `ENTER` key. */
  onChange?: (newValue: string) => void;
  /** Callback on every modification. */
  onEdited?: (tmpValue: string) => void;
  /** Default selected value. */
  className?: string;
  /** Additional style for the `<dov/>` container of Raiods */
  style?: React.CSSProperties;
}

/**
   Text Field.
*/
export const Field = (props: FieldProps) => {
  const [current, setCurrent] = React.useState<string>();
  const { className = '', onChange, onEdited, value = '' } = props;
  const disabled = onChange ? DISABLED(props) : true;
  const theValue = current ?? value;
  const ONCHANGE = (evt: React.ChangeEvent<HTMLInputElement>) => {
    let text = evt.target.value || '';
    setCurrent(text);
    onEdited && onEdited(text);
  };
  const ONKEYPRESS = (evt: React.KeyboardEvent) => {
    switch (evt.key) {
      case 'Enter':
        setCurrent(undefined);
        onChange && current && onChange(current);
        break;
      case 'Escape':
        setCurrent(undefined);
        break;
    };
  };
  return (
    <input id={props.id} type='text'
      autoFocus={!disabled && props.autoFocus}
      value={theValue}
      className={'dome-xField ' + className}
      style={props.style}
      disabled={disabled}
      placeholder={props.placeholder}
      onKeyPress={ONKEYPRESS}
      onChange={ONCHANGE} />
  );
};

// --------------------------------------------------------------------------
