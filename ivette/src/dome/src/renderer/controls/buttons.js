// --------------------------------------------------------------------------
// --- Buttons, Check Boxes and Radio Groups
// --------------------------------------------------------------------------

/**
   @packageDocumentation
   @module dome/controls/buttons
   @description

   Those controls may work as _controlled_ or _uncontrolled_ components,
   although you shall not use both modes at the same times.

*/

import React from 'react' ;
import { Icon } from './icons' ;
import './style.css' ;

const DISABLED = ({ disabled=false, enabled=true }) => !!disabled || !enabled ;
const TRIGGER = (onClick) => (evt) => {
  evt.stopPropagation();
  if (onClick) onClick();
};

// --------------------------------------------------------------------------
// --- LCD
// --------------------------------------------------------------------------

const LCDCLASS = 'dome-xButton dome-xBoxButton dome-text-code dome-xButton-lcd ' ;

/**
   @summary Button-like label.
   @property {string} [text] - Textual content (prepend to children components, if any)
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [title] - Label tooltip (optional)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional CSS style
*/
export const LCD = (props) => (
  <label className={LCDCLASS + (props.className || '')}
         title={props.title}
         style={props.style} >
    {props.icon && <Icon id={props.icon}/>}
    {props.label}
    {props.text}
    {props.children}
  </label>
);

// --------------------------------------------------------------------------
// --- Led
// --------------------------------------------------------------------------

/**
   @summary Led indicator.
   @property {string} [status] - Led status and color (default: inactive)
   @property {boolean} [blink] - Led blinking (default: false)
   @property {string} [title] - Led tooltip (optional)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional CSS style
   @description
   LED status can be:
   - `'inactive'`: off (or any falsy value)
   - `'active'`: blue color
   - `'positive'`: green color
   - `'negative'`: red color
   - `'warning'`: orange color
*/
export const LED = (props) => {
  const classes = 'dome-xButton-led dome-xButton-led-'
        + (props.status || 'inactive')
        + (props.blink ? ' dome-xButton-blink' : '')
        + (props.className ? ' ' + props.className : '') ;
  return (<div className={classes} title={props.title} style={props.style} />);
};

// --------------------------------------------------------------------------
// --- Button
// --------------------------------------------------------------------------

const VISIBLE = { visibility:'visible' };
const HIDDEN  = { visibility:'hidden'  };

const LABEL = ({disabled,label}) => (
  <div className="dome-xButton-label" >
    <div className="dome-xButton-label dome-control-enabled"
         style={disabled ? HIDDEN : VISIBLE} >{label}</div>
    <div className="dome-xButton-label dome-control-disabled"
         style={disabled ? VISIBLE : HIDDEN}>{label}</div>
  </div>
);

/**
   @summary Standard Button.
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [label] - Button label
   @property {string} [title] - Optional tooltip
   @property {boolean} [selected] - Selected button
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {boolean} [visible] - Defaults to `true`
   @property {boolean} [display] - Defaults to `true`
   @property {boolean} [focusable] - May gain focus
   @property {string} [kind] - Styled button (see below)
   @property {boolean} [blink] - Blinking button
   @property {function} [onClick] - On-click callback
   @property {string} [className] - Additional class
   @property {object} [style] - Additional style
   @description
   The different available kinds for styling a button are:
   - `'default'`: normal button;
   - `'active'`: active normal button;
   - `'primary'`: primary button, in blue;
   - `'warning'`: warning button, in orange;
   - `'positive'`: positive button, in green;
   - `'negative'`: negative button, in red.

   Buttons without focus can not be triggered with the Enter key.
*/
export const Button = (props) => {
  const disabled = DISABLED(props);
  const { focusable=false, kind='default',
          visible=true, display=true, blink=false,
          selected, icon, label, className='' } = props;
  const theClass = 'dome-xButton dome-xBoxButton dome-xButton-'
        + (selected ? 'selected' : kind)
        + (!blink ? '' : ' dome-xButton-blink')
        + (visible ? '' : ' dome-control-hidden')
        + (display ? '' : ' dome-control-erased')
        + (className ? ' ' + className : '')
  ;
  const nofocus = focusable ? undefined : true ;
  return (
    <button type='button'
            className={theClass}
            disabled={disabled}
            onClick={TRIGGER(props.onClick)}
            title={props.title}
            style={props.style}
            tabIndex={ nofocus && -1 }
            onMouseDown={ nofocus && ((evt) => evt.preventDefault()) }
      >
      {icon && <Icon id={icon}/>}
      {label && <LABEL disabled={disabled} label={label}/>}
    </button>
  );
};

// --------------------------------------------------------------------------
// --- Icon Button
// --------------------------------------------------------------------------

/**
   @summary Circled Icon Button.
   @property {string} [icon] - Label icon (optional, on left side)
   @property {string} [title] - Optional tooltip
   @property {boolean} [selected] - Selected button
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {boolean} [visible] - Defaults to `true`
   @property {boolean} [display] - Defaults to `true`
   @property {boolean} [focusable] - May gain focus
   @property {string} [kind] - Styled button (see below)
   @property {function} [onClick] - On-click callback
   @property {string} [className] - Additional class
   @property {object} [style] - Additional style
   @description
   The different available kinds for styling a button are:
   - `'default'`: normal button;
   - `'active'`: active normal button;
   - `'primary'`: primary button, in blue;
   - `'warning'`: warning button, in orange;
   - `'positive'`: positive button, in green;
   - `'negative'`: negative button, in red.

   Buttons without focus can not be triggered with the Enter key.
*/
export const CircButton = (props) => {
  const disabled = DISABLED(props);
  const { focusable=false, kind='default',
          visible=true, display=true,
          selected, icon, label, className='' } = props;
  const theClass = 'dome-xButton dome-xCircButton dome-xButton-'
        + (selected ? 'selected' : kind)
        + (visible ? '' : ' dome-control-hidden')
        + (display ? '' : ' dome-control-erased')
        + (className ? ' ' + className : '') ;
  const nofocus = focusable ? undefined : true ;
  return (
    <button type='button'
            className={theClass}
            disabled={disabled}
            onClick={TRIGGER(props.onClick)}
            title={props.title}
            style={props.style}
            tabIndex={ nofocus && -1 }
            onMouseDown={ nofocus && ((evt) => evt.preventDefault()) }
      >
      {icon && <Icon offset={-1} id={icon}/>}
    </button>
  );
};

// --------------------------------------------------------------------------
// --- Icon Button
// --------------------------------------------------------------------------

/**
   @summary Borderless Icon Button.
   @property {string} icon - Icon identifier
   @property {number} size - Icon size (default `12`)
   @property {number} offset - Icon offset
   @property {string} [title] - Optional tooltip
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {boolean} [visible] - Defaults to `true`
   @property {boolean} [display] - Defaults to `true`
   @property {boolean} [selected] - Defaults to `false`
   @property {function} [onClick] - Callback (receives the newly expected value)
   @property {string} [kind] - Styled button (see below)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional style
   @description
   The different available kinds for styling a button are:
   - `'default'`: normal button;
   - `'active'`: active normal button;
   - `'warning'`: warning button, in orange;
   - `'positive'`: positive button, in green;
   - `'negative'`: negative button, in red.
*/
export const IconButton = (props) => {
  const disabled = DISABLED(props);
  const {
    icon, size, title,
    visible=true, display=true, selected,
    kind='default'
  } = props ;
  const className = 'dome-xIconButton'
        + ' dome-xIconButton-' + (selected ? 'selected' : kind)
        + (disabled ? ' dome-control-disabled' : ' dome-control-enabled')
        + (visible ? '' : ' dome-control-hidden')
        + (display ? '' : ' dome-control-erased')
        + (props.className ? ' ' + props.className : '') ;
  return (
    <Icon
      size={size} id={icon} title={title}
      style={props.style}
      offset={props.offset}
      className={className}
      onClick={TRIGGER(disabled ? undefined : props.onClick)}
      />
  );
};

// --------------------------------------------------------------------------
// --- CheckBox
// --------------------------------------------------------------------------

const CHECKBOX_ENABLED = 'dome-control-enabled dome-xCheckbox ' ;
const CHECKBOX_DISABLED = 'dome-control-disabled dome-xCheckbox ' ;

/**
   @summary CheckBox with its label.
   @property {string} [label] - Button label
   @property {string} [title] - Optional tooltip
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {boolean} [value] - Checked or not (defaults to internal state)
   @property {function} [onChange] - Callback (receives the newly expected value)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional style
*/
export const Checkbox = (props) => {
  const disabled = DISABLED(props);
  const onChange = props.onChange && ((evt) => props.onChange(evt.target.checked)) ;
  const baseClass = disabled ? CHECKBOX_DISABLED : CHECKBOX_ENABLED ;
  const labelClass = props.className || '' ;
  return (
    <label
      title={props.title}
      style={props.style}
      className={baseClass + labelClass} >
      <input type="checkbox"
             disabled={disabled}
             checked={props.value}
             onChange={onChange} />
      {props.label}
    </label>
  );
};

// --------------------------------------------------------------------------
// --- Switch
// --------------------------------------------------------------------------

/**
   @summary Switch with its label.
   @property {string} [label] - Button label
   @property {string} [title] - Optional tooltip
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {boolean} [visible] - Defaults to `true`
   @property {boolean} [display] - Defaults to `true`
   @property {boolean} [value] - Checked or not (defaults to internal state)
   @property {function} [onChange] - Callback (receives the newly expected value)
   @property {string} [className] - Additional class
   @property {object} [style] - Additional style
*/
export const Switch = (props) => {
  const disabled = DISABLED(props);
  const { visible=true, display=true } = props ;
  const onChange = props.onChange && ((evt) => props.onChange(evt.target.checked)) ;
  const iconId = props.value ? 'SWITCH.ON' : 'SWITCH.OFF' ;
  const onClick = (disabled || !props.onChange)
        ? undefined : () => props.onChange(!props.value) ;
  const className = 'dome-xSwitch '
        + (disabled ? 'dome-control-disabled' : 'dome-control-enabled')
        + (visible ? '' : ' dome-control-hidden')
        + (display ? '' : ' dome-control-erased')
        + (props.className ? ' ' + props.className : '') ;
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

/**
   @summary Radio Button with its label.
   @property {string} [label] - Button label
   @property {string} [title] - Optional tooltip
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {any} [value] - Associated value to the radio
   @property {any} [selection] - Currently selected value
   @property {function} [onSelection] - On-click callback
   @property {string} [className] - Additional class
   @property {object} [style] - Additional style
   @description
   See also [[RadioGroup]].

   <strong>Note:</strong> property `value` and `selection` are consistent
   with HTML standards and DOM element properties.
*/
export const Radio = (props) => {
  const disabled = DISABLED(props);
  const checked = props.value === props.selection ;
  const onChange = props.onSelection && (() => props.onSelection(props.value)) ;
  const baseClass = disabled ? CHECKBOX_DISABLED : CHECKBOX_ENABLED ;
  const labelClass = props.className || '' ;
  return (
    <label
      title={props.title}
      style={props.style}
      className={baseClass + labelClass} >
      <input type="radio" disabled={disabled} checked={checked} onChange={onChange} />
      {props.label}
    </label>
  );
};

// --------------------------------------------------------------------------
// --- Radio Group
// --------------------------------------------------------------------------

/**
   @class
   @summary Selector of Radio Buttons.
   @property {any} [value] - Currently selected value
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {function} [onChange] - On-selection callback
   @property {string} [className] - Additional class of the container `<div>`
   @property {object} [style] - Additional style of the container `<div>`
   @description
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
export class RadioGroup extends React.Component {

  constructor(props) {
    super(props);
    this.state = { value: props.value };
    this.onChange = this.onChange.bind(this);
  }

  componentDidUpdate() {
    let v = this.props.value ;
    if (v && this.state.value !== v) this.setState( { value: v } );
  }

  onChange(value) {
    this.setState( { value } );
    this.props.onChange && this.props.onChange( value );
  }

  render() {
    const groupdisabled = DISABLED(this.props);
    const { className='', style } = this.props ;
    const selection = this.state.value ;
    const makeRadio = (radio) => {
      const disabled = groupdisabled || DISABLED(radio.props) ;
      const { onSelection: onRadioSelect } = radio.props ;
      const onSelection =
            onRadioSelect
            ? (v) => { onRadioSelect(v) ; this.onChange(v); }
            : this.handleSelect ;
      return React.cloneElement( radio , { selection , disabled , onSelection } , null );
    } ;
    return (
      <div className={ 'dome-xRadio-group ' + className } style={style}>
        {React.Children.map( this.props.children , makeRadio )}
      </div>
    );
  }

}

// --------------------------------------------------------------------------
// --- Selector
// --------------------------------------------------------------------------

/**
   @summary Menu Button.
   @property {string} [placeholder] - Label of undefined selection
   @property {string} [title] - Optional tooltip
   @property {any} [value] - Currently selected value
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {function} [onChange] - On-selection callback
   @property {string} [className] - Additional class
   @property {object} [style] - Additional style
   @property {string} [id] - Select identifier
   @description
   Childrens of the `Select` shall be standard `<option>` or `<optgroup>` HTML
   elements. When the `placeholder` property is set, an additional option is provided
   and associated with any `undefined` value.

   The selected value of the group is broadcasted to the provided options, and their callbacks
   linked to the button automatically.

   **Remark:** most non-positionning CSS properties might not work on the `<select>` element due
   to the native rendering used by Chrome.
   You might use `-webkit-appearance: none` to cancel this behavior, you will have to restyle the
   component entirely, which is quite ugly by default.
*/
export const Select = (props) => {
  const disabled = DISABLED(props);
  const onChange = props.onChange && ((e) => props.onChange(e.target.value));
  const className = props.className || '' ;
  return (
    <select
      id={props.id}
      disabled={disabled}
      className={'dome-xSelect ' + className}
      style={props.style}
      title={props.title}
      value={props.value || ''}
      onChange={onChange}
      >
      {props.placeholder && props.placeholder !=='' && (
        <option disabled value=''>— {props.placeholder} —</option>
      )}
      {props.children}
    </select>
  );
};

// --------------------------------------------------------------------------
// --- Text Input
// --------------------------------------------------------------------------

/**
   @summary Text Field.
   @property {string} [value] - Field initial content
   @property {string} [edited] - Field current value
   @property {boolean} [enabled] - Defaults to `true`
   @property {boolean} [disabled] - Defaults to `false`
   @property {boolean} [autoFocus] - Defaults to `false`
   @property {function} [onChange] - Update callback (on every edit, debounced)
   @property {function} [onEnter] - Enter callback (on Enter or Return key)
   @property {string} [title] - Field tooltip text
   @property {string} [placeholder] - Input field place holder
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {string} [id] - Input field identifier
   @description
   Field with a Text Input element. The default latency is set to 600ms.
*/
export const Field = (props) => {
  const [ current, setCurrent ] = React.useState(props.value);
  const disabled = DISABLED(props);
  const className = props.className || '' ;
  const { edited, onChange, onEnter } = props ;
  const value = edited === undefined ? current : edited ;
  const ONCHANGE = (evt) => {
    let text = evt.target.value || '' ;
    if (edited === undefined) setCurrent(text);
    onChange && onChange(text);
  };
  const ONKEYPRESS = (evt) => {
    if (evt.key === 'Enter' && onEnter) onEnter(value);
  };
  return (
    <input id={props.id} type='text'
           autoFocus={!disabled && props.autoFocus}
           value={value}
           className={'dome-xField ' + className}
           style={props.style}
           disabled={disabled}
           placeholder={props.placeholder}
           onKeyPress={ONKEYPRESS}
           onChange={ONCHANGE} />
  );
};

// --------------------------------------------------------------------------
