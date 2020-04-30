// --------------------------------------------------------------------------
// --- Form Layout
// --------------------------------------------------------------------------

/** @module dome/layout/forms */

import _ from 'lodash' ;
import React from 'react' ;
import * as Dome from 'dome' ;
import { SVG } from 'dome/controls/icons' ;
import { Checkbox, Radio, Select as Selector } from 'dome/controls/buttons' ;
import './style.css' ;

// --------------------------------------------------------------------------
// --- Utilities
// --------------------------------------------------------------------------

const Context = React.createContext();

const SELECT = (props,context) => props === undefined ? context : props ;
const ACCESS = (props,context,path) => props === undefined ? _.get(context,path) : props ;
const CONDITION = (context,cond,undef) => {
  switch(typeof(cond)) {
  case 'undefined':
    return undef;
  case 'string':
  case 'array':
    return _.get(context,cond);
  default:
    return cond;
  }
};

const COMBINE = (a,b) => {
  if (a === undefined) return b;
  if (b === undefined) return a;
  return (...args) => { a(...args); b(...args); };
};

const UPDATE = (value,error,path,callback) => callback &&
      ((v,e) => {
        let update = value || {} ;
        _.set( update, path, v );
        let errors ;
        if (error || e) {
          errors = error || {} ;
          _.set( errors, path, e );
          if (!_.find(errors))
            errors = undefined;
        }
        callback(update,errors);
      });

const CHECK = (validate,v) => {
  if (typeof(validate) === 'function')
    return validate(v);
  if (_.isRegExp(validate))
    return validate.test(v);
  return validate;
};

const ERROR = (validate,warning,v) => {
  let ok = CHECK(validate,v);
  switch(ok) {
  case undefined:
  case true:
    return undefined ;
  default:
    return ok || warning ;
  }
};

const VALIDATE = (validate,warning,callback) => {
  if (!validate) return callback;
  return ((v,e) => {
    if (!callback) return;
    else if (v===undefined || e) callback(v,e);
    else {
      let e = ERROR(validate,warning,v);
      callback(v,e);
    }
  });
};

const RENDER = (children,context) => (
  children ?
    ( typeof(children)==='function'
      ? children(context)
      : children )
    : null
);

const ONCHANGE = (onChange) =>
      typeof(onChange)==='function'
      ? (evt) => onChange(evt.target.value)
      : undefined ;

const CLASSES = (...args) => _.filter(args).join(' ');

// --------------------------------------------------------------------------
// --- Filtering DataFlow
// --------------------------------------------------------------------------

const FILTER_ERROR = (err) =>
      err ? _.toString(err) : 'Invalid input, enter a new value to fix'
;

class FILTER extends React.Component
{

  constructor(props) {
    super(props);
    this.state = this.forward();
    this.onChange = this.onChange.bind(this);
    if (props.period)
      this.backward = _.debounce(this.backward,props.period);
  }

  componentDidUpdate(prevProps) {
    const props = this.props ;
    if (props.value !== prevProps.value ||
        props.error !== prevProps.error)
      this.setState(this.forward());
  }

  onChange(value,error) {
    this.setState({value,error});
    this.backward(value,error);
  }

  forward() {
    try {
      const { input , value , error } = this.props ;
      return { value: input ? input(value) : value, error };
    } catch(err) {
      return { value: undefined, error: FILTER_ERROR(err) };
    }
  };

  backward(v,e)
  {
    const { output, onChange } = this.props ;
    try {
      if (output) v = output(v);
    } catch(err) {
      this.setState({error: FILTER_ERROR(err)});
      return;
    }
    if (onChange) onChange(v,e);
  }

  render() {
    const { disabled, children } = this.props ;
    const { value, error } = this.state ;
    const context = { onChange: this.onChange, disabled, value, error };
    return (
      <Context.Provider value={context}>
        {RENDER(children,context)}
      </Context.Provider>
    );
  }

}

// --------------------------------------------------------------------------
// --- Generic Field
// --------------------------------------------------------------------------

const PERIOD = (latency) => {
  switch(typeof(latency)) {
  case 'undefined': return 0;
  case 'number': return latency;
  default:
    return latency ? 600 : 0 ;
  }
};

/**
   @summary Generic context wrapper for field values.
   @property {string} [path] - select a property in the context value (and error)
   @property {any} [value] - set the inherited or edited value
   @property {any} [error] - set the inherited or edited error
   @property {function} [input] - pre-processing of input values (after `path` selection)
   @property {function} [output] - post-processing of output values (before `path` update)
   @property {function} [onChange] - callback for edited values and errors
   @property {boolean|string|function} [disabled] - disabled field (default is `false`)
   @property {boolean|string|function} [enabled] - conditional enabling (default is `true`)
   @property {boolean|string|function} [visible] - conditional rendering (default is `true`)
   @property {boolean|string|function} [hidden] - conditional hidding (default is `false`)
   @property {boolean|regexp|function} [validate] - validation of the updated value
   @property {string} [warning] - error message in case `validate` returns `false`
   @property {boolean|number} [latency] - delay validation and propagation callbacks
   @property {boolean} [state] - maintain a locally edited state (default is `false`)
   @property {React.children|function} [children] - elements to render in the new context
   @description

Forms are based on a local context that can be modified by using this multi-purposed
component. The local context consists of:
- `value`: the currently edited value;
- `error`: the last emitted error for this value;
- `onChange(value[,error])`: the callback to be used on updates;
- `disabled`: whether this value can be edited or not.

Undefined properties are inherited from the context. If the `path` property is defined,
the `<Select>` component extract the associated value and error from the inherited context.
When both `path` and `value` properties are defined, the specified value takes the precedence.
Access and updates of `path` are performed with the lodash `_.get()` and `_.set()` functions.
Although, the `<Select>` might perform in-place modifications of previous object or array value.
Use `_.cloneDeep()` to build a (recursive) copy of some value.

Before being processed downward, the inherited or selected value can be transformed.
The `input` function is applied on incomming value, and `output` function is applied
on updated values.

The specified callback `onChange` is invoked with the updated value and error. The callback
inherited from the context is _also_ notified. When the `path` property is set,
the contextual callback will be notified with the full context values and errors,
updated with local changes to the selected path.

The validation callback is invoked on updates. It shall return `undefined`
or a string explaining why the value is invalid. Boolean are also accepted,
leading to an error string defined by the `warning` property, which defaults to `"Invalid field"`.
Alternatively, `validate` can be a regexp that is tested against the value.
For instance, to accept only numbers, you can use `validate={/^[0-9]+$/}`
and `warning='Must be a number'`.

To avoid too many callback and validation checks, typically for text-based fields, it is possible to
set a latency period before validating the input and emitting the callback. In such a case, a transient
local state for value and error is maintained until the edited value is stabilized, before performing
validation and upward propagation. The default lantency period is 600ms.

It is possible to conditionally enabling, disabling or hiding the content by using
the `disabled`, `enabled`, `visible` and `hidden` properties. They all can be boolean values,
or path in or function of the inherited value. For instance, `<Select path='f.g' enabled='f.ok'/>`
would allow to edit the value `value.f.g`, but disable edition when `value.f.ok` is falsy.
Remark that if the inherited context is disabled, the selected content is disabled too.

When latency, or input/output transformation are required, a local state is maintained.
Otherwized, context and callbacks are propagated upward and backward. However, you can
force this local state to be maintained by specifying the property `state` to `true`.
This shall be used only at top-level for implementing a non-controlled component.

*/
export function Select({
  path, latency,
  defaultValue:def,
  children, state,
  ...props
}) {
  let context = React.useContext( Context );
  if (!CONDITION(context.value,props.visible,true) ||
      CONDITION(context.value,props.hidden,false))
    return null;
  let disabled = context.disabled
      || CONDITION(context.value,props.disabled,false)
      || !CONDITION(context.value,props.enabled,true);
  let value,error,callback ;
  if (path) {
    value = ACCESS( props.value , context.value , path );
    error = ACCESS( props.error , context.error , path );
    if (!disabled)
      callback = UPDATE(context.value,context.error,path,context.onChange);
  } else {
    value = SELECT( props.value , context.value );
    error = SELECT( props.error , context.error );
    if (!disabled)
      callback = context.onChange;
  };

  let onChange ;
  if (!disabled) {
    onChange = VALIDATE( props.validate, props.warning,
                         COMBINE(props.onChange,callback) );
  }

  if (props.validate && value && !error) {
    error = ERROR( props.validate, props.warning, value );
  }

  let newContext = { value,error, disabled, onChange };
  if (state || latency || props.input || props.output) {
    return (
      <FILTER period={PERIOD(latency)}
              input={props.input}
              output={props.output}
              {...newContext}>
        {children}
      </FILTER>
    );
  } else
    return (
      <Context.Provider value={newContext}>
        {RENDER(children,newContext)}
      </Context.Provider>
    );
}

// --------------------------------------------------------------------------
// --- Form Container
// --------------------------------------------------------------------------

/**
   @summary Form Container.
   @property {string} [className] - Container additional class
   @property {object} [style] - Container additional style
   @property {object} [value] - Set the form context value
   @property {object} [error] - Set the form context error
   @property {boolean} [disabled] - Disables the form (default is `false`)
   @property {onChange} [function] - Callback to updated `(value,error)`
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @property {React.children|function} [children] - Fields to populate the form
   @description

   Setup a form context with the provided values.
   A local state is maintained unless you fully control the `value` and `error`
   properties. You may also specify any other properties of the
   [Select](module-dome_layout_forms.Select.html) filter component.

*/

export const Form = ({className,style,...props}) =>
  (
    <div className={CLASSES('dome-xForm-grid',className)}>
      <Context.Provider value={{}}>
        <Select state {...props}/>
      </Context.Provider>
    </div>
  );

// --------------------------------------------------------------------------
// --- Generic Error Badge
// --------------------------------------------------------------------------

const ERROR_MSG = (error) => {
  switch(typeof(error)) {
  case 'undefined':
    return undefined ;
  case 'string':
    return error;
  case 'object':
  case 'array':
    var n = 0;
    _.forEach(error,(err) => { if (err) n++; });
    if (n==1) return 'Invalid field' ;
    if (n>1) return n + ' Invalid fields' ;
    return undefined ;
  default:
    return _.toString(error);
  }
};

/**
   @summary Warning badge with description.
   @property {string} [warn] - the short message (hovered)
   @property {number} [offset] - the label offset (Cf. field)
   @property {any} [error] - the error description (in tooltip)
   @property {full} [boolean] - full error message on error (no tooltip, default `false`)
   @description
   Display a warning badge with a tooltip when the `error` is not
   undefined. Otherwize, renders nothing.
*/
export const Warning = ({full,warn,offset,error,width}) => {
  let msg = ERROR_MSG(error);
  return msg ? (
    <div className='dome-xIcon dome-xForm-error'
         style={{top: (offset-2)}} >
      <SVG id='WARNING' size={11} title={full ? undefined : msg}/>
      {(full
        ? <span className='dome-xForm-warning' style={{width: 'max-content'}}>{msg}</span>
        : <span className='dome-xForm-warning'>{warn}</span>
       )}
    </div>
  ) : null ;
};

// --------------------------------------------------------------------------
// --- Section Container
// --------------------------------------------------------------------------

const TITLE_ENABLED = 'dome-text-title' ;
const TITLE_DISABLED = 'dome-text-title dome-disabled' ;

/**
   @summary Expandable Section sub-form.
   @property {string} label - Section title
   @property {string} [title] - Tooltip text
   @property {string} [path] - Fields selection
   @property {string} [settings] - User's settings for making fold/unfold state persistent
   @property {boolean} [unfold] - Default fold/unfold state (default is `false`)
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @property {React.children|function} [children] - Section field content
   @description
   Wraps some fields inside a foldable section.
   When unfolded, the section fields are not visible but still rendered.
*/

export function Section(props)
{

  let [ unfold, setUnfold ] = Dome.useState(props.settings,props.unfold);

  const onSwitch = () => setUnfold(!unfold);

  const { label, title, path, children, ...otherProps } = props ;

  return (
    <Select path={path} {...otherProps}>
      {(context) => (
        <React.Fragment>
          <div className='dome-xForm-section'>
            <div className='dome-xForm-fold' onClick={onSwitch}>
              <SVG id={unfold?'TRIANGLE.DOWN':'TRIANGLE.RIGHT'} size={11}/>
            </div>
            <label className={ (path && context.disabled) ? TITLE_DISABLED : TITLE_ENABLED }
                   title={title}>
              {label}
            </label>
            { unfold && path && <Warning full error={context.error}/> }
          </div>
          { unfold && RENDER(children,context) }
          { unfold && <div className='dome-xForm-hsep'/> }
        </React.Fragment>
      )}
    </Select>
  );
}

// --------------------------------------------------------------------------
// --- Block Container
// --------------------------------------------------------------------------

/**
   @summary Full width form block.
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @property {React.children|function} [children] - Block content
   @description
   Wraps its children inside the entire width of the form.
*/

export const Block = ({ children, ...props }) => (
  <Select {...props}>
    {(context) => (
      <div className='dome-xForm-block'>
        {RENDER(children,context)}
      </div>)}
  </Select>
);

// --------------------------------------------------------------------------
// --- Generic Fields
// --------------------------------------------------------------------------

let fid = 0 ;

const LABEL_ENABLED  = 'dome-xForm-label dome-text-label';
const LABEL_DISABLED = 'dome-xForm-label dome-text-label dome-disabled';
const FIELD_ENABLED  = 'dome-xForm-field dome-text-label';
const FIELD_DISABLED = 'dome-xForm-field dome-text-label dome-disabled';

/**
   @class
   @summary Generic Custom Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {number} [offset] - Vertical label offset (for baseline alignment)
   @property {boolean|string} [warn] - Display errors (default: `true`)
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @property {React.children|function} [children] - Custom field content
   @description

Field layout inside a Form container.
The custom field component is positionned on the left of the label, right-aligned.
The label itself is left-aligned with the other fields.

The Field component setup a [Select](module-dome_layout_forms.Select.html)
filter for your custom component. Additionnaly, if you use a custom function rendering,
the context is enriched with the `id` of the `<label/>` DOM element of the label, that
you can use with `<input htmlFor={id}/>` as custom field component.

A warning badge is displayed on the right of your custom component, unless `warn:false`
is specified. When hovered, the badge displays `Error` or the specified `string`. When
hovered for a while, a full description of the error is displayed in a tooltip.
*/

export class Field extends React.Component
{

  constructor(props) {
    super(props);
    this.id = props.id || 'DOME$' + (fid++) ;
  }

  render() {
    const id = this.id ;
    const { label, title, offset=1, children, warn='Error', ...props } = this.props ;
    return (
      <Select {...props}>
        {(context) => (
          <React.Fragment>
            <label className={context.disabled ? LABEL_DISABLED : LABEL_ENABLED}
                   style={{top: offset}}
                   htmlFor={id}
                   title={title}>
              {label}
            </label>
            <div className={context.disabled ? FIELD_DISABLED : FIELD_ENABLED}>
              {RENDER(children,Object.assign(context,{id}))}
              {warn && <Warning offset={offset} warn={warn} error={context.error}/>}
            </div>
          </React.Fragment>
        )}
      </Select>
    );
  }

}

// --------------------------------------------------------------------------
// --- Field List Container
// --------------------------------------------------------------------------

/**
   @summary Field List Container.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {boolean} [warn] - Display errors (default: `false`)
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @property {React.children|function} [children] - List field content
   @description

Render its field children in a right-aligned list on the left of the label.
Typically designed for a list of checkboxes and radio buttons.

Inside the field list, the field-label column no more exists. Hence, text field labels are
typically never displayed when placed in a field list.

*/
export const FieldList = ({ label, title, warn=false, children, ...props }) => (
  <Field label={label} title={title} warn={warn} {...props}>
    <div className='dome-xForm-list'>
      {children}
    </div>
  </Field>
);

// --------------------------------------------------------------------------
// --- Text Field
// --------------------------------------------------------------------------

/**
   @summary Text Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [placeholder] - Input field place holder
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field with a Text Input element. The default latency is set to 600ms.
*/
export const FieldText = ({ className, style, latency=true, placeholder, ...props }) => (
  <Field offset={4} latency={latency} {...props}>
    {({id,value,disabled,onChange}) => (
      <input id={id}
             type='text'
             value={value || ''}
             className={CLASSES('dome-xForm-text-field',className)}
             style={style}
             disabled={disabled}
             placeholder={placeholder}
             onChange={ONCHANGE(onChange)}
             />
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- Code Field
// --------------------------------------------------------------------------

/**
   @summary Monospaced Text Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [placeholder] - Input field place holder
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field with a Text Input element. The default latency is set to 600ms.
*/
export const FieldCode = ({ className, style, latency=true, placeholder, ...props }) => (
  <Field offset={4} latency={latency} {...props}>
    {({id,value,disabled,onChange}) => (
      <input id={id}
             type='text'
             value={value || ''}
             className={CLASSES('dome-xForm-text-field dome-text-code',className)}
             style={style}
             disabled={disabled}
             placeholder={placeholder}
             onChange={ONCHANGE(onChange)}
             />
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- TextArea Field
// --------------------------------------------------------------------------

/**
   @summary Text Area Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [className] - Input field additional class
   @property {string} [placeholder] - Input field place holder
   @property {number} [cols] - Number of columns (default 35, min 5)
   @property {number} [rows] - Number of lines (default 5, min 2)
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field with a Text Input element. The default latency is set to 900ms.
*/
export const FieldTextArea = ({ className, style, cols=35, rows=5,
                                placeholder, latency=900, ...props }) => (
  <Field offset={4} latency={latency} {...props}>
    {({id, value, disabled, onChange }) => (
      <textarea id={id}
                type='text'
                className={CLASSES('dome-xForm-textarea-field',className)} style={style}
                disabled={disabled}
                wrap='off' spellchecker='true'
                value={value || ''}
                cols={Math.max(5,cols)}
                rows={Math.max(1,rows-1)}
                placeholder={placeholder}
                onChange={ONCHANGE(onChange)}
                />
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- CodeArea Field
// --------------------------------------------------------------------------

/**
   @summary Text Area Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [className] - Input field additional class
   @property {string} [placeholder] - Input field place holder
   @property {number} [cols] - Number of columns (default 35, min 5)
   @property {number} [rows] - Number of lines (default 5, min 2)
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field with a Text Input element. The default latency is set to 900ms.
*/
export const FieldCodeArea = ({ className, style, cols=35, rows=5,
                                placeholder, latency=900, ...props }) => (
  <Field offset={4} latency={latency} {...props}>
    {({id, value, disabled, onChange }) => (
      <textarea id={id}
                ref={this.area}
                type='text'
                className={CLASSES('dome-xForm-textarea-field dome-text-code',className)} style={style}
                disabled={disabled}
                wrap='off' spellchecker='false'
                value={value || ''}
                cols={Math.max(5,cols)}
                rows={Math.max(1,rows-1)}
                placeholder={placeholder}
                onChange={ONCHANGE(onChange)}
                />
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- Number Field
// --------------------------------------------------------------------------

const PARSE_NUMBER = (v,debug) => {
  let n = parseFloat(v);
  if (Number.isNaN(n)) {
    let msg = "Invalid number format";
    if (debug) {
      let txt = _.toString(v);
      if (txt.length > 20) txt = txt.substring(0,19)+'…' ;
      msg += ": «" + txt + "»" ;
    }
    throw msg ;
  }
  return n;
};
const TEXT_OF_NUMBER = (v) => v===undefined ? '' : PARSE_NUMBER(v,true).toLocaleString('en');
const NUMBER_OF_TEXT = (s) => s==='' ? undefined : PARSE_NUMBER(s.replace(/[ ,]/g,''));

/**
   @summary Number Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [placeholder] - Input field place holder
   @property {string} [units] - Number units or currency
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field to edit number values with a Text Input element.
   The default latency is set to 600ms. Numbers are rendered in the english locale, grouping thousands
   with «,». The currency or units is displayed on the right of the field. The edited text
   is converted back and forth to number values with `parseFloat`.
*/
export const FieldNumber =
  ({ className, style, latency=true, units, placeholder, ...props }) => (
    <Field latency={latency}
           input={TEXT_OF_NUMBER}
           output={NUMBER_OF_TEXT}
           {...props}>
      {({id,value,disabled,onChange}) => (
        <React.Fragment>
          <input id={id}
                 type='text'
                 value={value || ''}
                 className={CLASSES('dome-xForm-number-field',className)}
                 style={style}
                 disabled={disabled}
                 placeholder={placeholder}
                 onChange={ONCHANGE(onChange)}
                 />
        {units && <label className='dome-text-label dome-xForm-units'>{units}</label>}
        </React.Fragment>
      )}
    </Field>
  );

// --------------------------------------------------------------------------
// --- Spinner field
// --------------------------------------------------------------------------

const PARSE_INT = (v,debug) => {
  let n = parseInt(v);
  if (Number.isNaN(n)) {
    let msg = "Invalid number format";
    if (debug) {
      let txt = _.toString(v);
      if (txt.length > 20) txt = txt.substring(0,19)+'…' ;
      msg += ": «" + txt + "»" ;
    }
    throw msg ;
  }
  return n;
};
const TEXT_OF_INT = (v) => v===undefined ? '' : PARSE_INT(v,true);
const INT_OF_TEXT = (s) => s==='' ? undefined : PARSE_INT(s);

const INT_RANGE = (min,max,warning) => (v) =>
      (min <= v && v <= max) ? undefined :
      warning || 'Range ' + min + '…' + max ;

/**
   @summary Spinner Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [placeholder] - Input field place holder
   @property {string} [units] - Number units or currency
   @property {number} [min] - Minimum value (default: 0)
   @property {number} [max] - Maximum value (default: 1000)
   @property {number} [step] - Stepper increment
   @property {string} [warning] - Out of bound message (default is explaining the range)
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field to edit integer numbers with a spinner element.
   The default latency is set to 600ms.
*/
export const FieldSpinner =
  ({ className, style, latency=true, units, placeholder, min=0, max=1000, step, ...props }) => (
    <Field latency={latency}
           input={TEXT_OF_INT}
           output={INT_OF_TEXT}
           validate={INT_RANGE(min,max)}
           {...props}>
      {({id,value,disabled,onChange}) => (
        <React.Fragment>
          <input id={id}
                 type='number'
                 value={ value === undefined ? '' : value }
                 className={CLASSES('dome-xForm-spinner-field',className)}
                 style={style}
                 min={min}
                 max={max}
                 step={step}
                 disabled={disabled}
                 placeholder={placeholder}
                 onChange={ONCHANGE(onChange)}
                 />
        {units && <label className='dome-text-label dome-xForm-units'>{units}</label>}
        </React.Fragment>
      )}
    </Field>
  );

// --------------------------------------------------------------------------
// --- Slider field
// --------------------------------------------------------------------------

const RESET_RANGE = (onChange,min,max) =>
      onChange && (() => onChange(Math.round( min + (max - min) / 2 )));

const SHOW_VALUE = (show,v) => {
  if (typeof(show)==='function')
    return show(v);
  if (v>0) return '+' + v ;
  if (v<0) return v ;
  return undefined ;
};

const SLIDER_VALUE = 'dome-text-label dome-xForm-units dome-xForm-slider-value ' ;
const SHOW_SLIDER = SLIDER_VALUE + 'dome-xForm-slider-show' ;
const HIDE_SLIDER = SLIDER_VALUE + 'dome-xForm-slider-hide' ;

class REVEAL extends React.Component {

  constructor(props) {
    super(props);
    this.state = { shown: false };
    this.fadeOut = _.debounce(this.fadeOut,PERIOD(props.latency));
  }

  componentDidUpdate(prevProps) {
    if (prevProps.value !== this.props.value) {
      this.fadeIn();
      this.fadeOut();
    }
  }

  fadeIn() {
    if (!this.state.shown) this.setState({ shown: true });
  }

  fadeOut() {
    if (this.state.shown) this.setState({ shown: false });
  }

  render() {
    const { show, value } = this.props ;
    const { shown } = this.state ;
    return (
      <label className={shown ? SHOW_SLIDER : HIDE_SLIDER}>{SHOW_VALUE(show,value)}</label>
    );
  }

}


/**
   @summary Slider Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {number} [min] - Minimum value (default: -24)
   @property {number} [max] - Maximum value (default: 24)
   @property {number} [step] - Stepper increment (default: 1)
   @property {boolean} [reset] - Reset on double click (default is `true`)
   @property {boolean|function} [show] - Display the selected value on the right (default is `true`)
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field to edit integer numbers with a spinner element.
   The default latency is set to 600ms. Double click on the slider reset it
   to its median value, unless `toreset` is specified. The `show` flag can be set to display
   the actual value when the slider is dragged. Alternatively, a function can be provided
   for computing the text to display for the dragged value.
*/
export const FieldSlider =
  ({ className, style, latency=true, min=-24, max=24, step=1, reset=true, show=true, ...props }) => (
    <Field latency={latency}
           input={TEXT_OF_INT}
           output={INT_OF_TEXT}
           {...props}>
      {({id,value,disabled,onChange}) => (
        <React.Fragment>
          <input id={id}
                 type='range'
                 value={ value === undefined ? '' : value }
                 className={CLASSES('dome-xForm-slider-field',className)}
                 style={style}
                 min={min}
                 max={max}
                 step={step}
                 disabled={disabled}
                 onDoubleClick={reset ? RESET_RANGE(onChange,min,max) : undefined}
                 onChange={ONCHANGE(onChange)}
                 />
          {show && <REVEAL latency={latency} show={show} value={value}/>}
        </React.Fragment>
      )}
    </Field>
  );

// --------------------------------------------------------------------------
// --- Date Field
// --------------------------------------------------------------------------

/**
   @summary Date Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [min] - Minimum date (default to `undefined`)
   @property {string} [max] - Maximum date (default to `undefined`)
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field with a Date Input element. The default latency is set to 600ms.
   The date is presented in english locale, with format `mm/dd/yyyy`, but the internal value
   is a string compatible with javascript `Date('yyyy-dd-mm')` format.
*/
export const FieldDate = ({ className, style, latency=true, min, max, ...props }) => (
  <Field latency={latency} {...props}>
    {({id,value,disabled,onChange}) => (
      <input id={id}
             type='date'
             value={value || ''} min={min} max={max}
             className={CLASSES('dome-xForm-date-field',className)}
             style={style}
             disabled={disabled}
             onChange={ONCHANGE(onChange)}
             />
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- Time Field
// --------------------------------------------------------------------------

/**
   @summary Time Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [min] - Minimum time (default to `undefined`)
   @property {string} [max] - Maximum time (default to `undefined`)
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field with a Time Input element. The default latency is set to 600ms.
   The time is presented in english locale, but its internal value is a string 'hh:mm'
   on 24h per day basis. This internal format can be used to form a valid javascript
   `Date('yyyy-mm-ddThh:mm')` object.
*/
export const FieldTime = ({ className, style, latency=true, min, max, ...props }) => (
  <Field latency={latency} {...props}>
    {({id,value,disabled,onChange}) => (
      <input id={id}
             type='time'
             value={value || ''} min={min} max={max}
             className={CLASSES('dome-xForm-time-field',className)}
             style={style}
             disabled={disabled}
             onChange={ONCHANGE(onChange)}
             />
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- Date Field
// --------------------------------------------------------------------------

/**
   @summary Color Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   Field with a Text Input element. The default latency is set to 600ms.
*/
export const FieldColor = ({ className, style, latency=true, ...props }) => (
  <Field latency={latency} {...props}>
    {({id,value,disabled,onChange}) => (
      <input id={id}
             type='color'
             value={value || '#ffffff'}
             className={CLASSES('dome-xForm-color-field',className)}
             style={style}
             disabled={disabled}
             onChange={ONCHANGE(onChange)}
             />
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- Select Field
// --------------------------------------------------------------------------

/**
   @summary Select Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {string} [placeholder] - Selector placeholder
   @property {string} [className] - Input field additional class
   @property {object} [style] - Input field additional style
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @property {option|optgroup} [children] - HTML options of the `<select>` element
   @description
   Field with a Select element. Children must be standard `<option>` and `<optgroup>` elements.
   Typically:

   ```
   <FieldSelect placeholder='Choose a value'>
      <option value='A'>Item A</option>
      <option value='B'>Item B</option>
      <option value='C'>Item C</option>
   </FieldSelect>
   ```

*/
export const FieldSelect = ({ className, style, children, placeholder, ...props }) => (
  <Field {...props}>
    {({id,value,disabled,onChange}) => (
      <Selector id={id}
                className={className}
                style={style}
                placeholder={placeholder}
                value={value}
                onChange={onChange} >
        {children}
      </Selector>
    )}
  </Field>
);

// --------------------------------------------------------------------------
// --- CheckBox Field
// --------------------------------------------------------------------------

/**
   @summary Checkbox Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {boolean} [inverted] - Inverted value (incompatible with `input` and `output` properties)
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   A check box field.
*/

export const FieldCheckbox = ({ label, title, inverted, ...props }) => {
  let transform = inverted ? (v) => !v : (v) => !!v ;
  return (
    <Select input={transform} output={transform} {...props}>
      {({value,disabled,onChange}) => (
        <Checkbox className={disabled ? FIELD_DISABLED : FIELD_ENABLED}
                  label={label} title={title}
                  disabled={disabled}
                  value={value} onChange={onChange}/>
      )}
    </Select>
  );
};

// --------------------------------------------------------------------------
// --- Radio Field
// --------------------------------------------------------------------------

/**
   @summary Radio Button Field.
   @property {string} [label] - Field label
   @property {string} [title] - Field tooltip text
   @property {any} [value] - Value associated with the radio button
   @property {any} [...props] - [Select](module-dome_layout_forms.Select.html) properties
   @description
   A radio button field.

   <strong>Note:</strong> there is no need for using a radio group here,
   since the selected value is taken from the context.
*/

export const FieldRadio = ({ label, title, value, ...props }) => {
  return (
    <Select {...props}>
      {({value:selection,disabled,onChange}) => (
        <Radio className={disabled ? FIELD_DISABLED : FIELD_ENABLED}
               label={label} title={title}
               disabled={disabled}
               value={value}
               selection={selection}
               onSelection={onChange}/>
      )}
    </Select>
  );
};

// --------------------------------------------------------------------------
