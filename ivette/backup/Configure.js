// --------------------------------------------------------------------------
// --- Module Configuration View
// --------------------------------------------------------------------------

import _ from 'lodash' ;
import React from 'react' ;
import Dome from 'dome' ;
import Dialogs from 'dome/dialogs' ;
import { Catch } from 'dome/errors' ;
import { Label } from 'dome/controls/labels' ;
import Box from 'dome/layout/boxes' ;
import Toolbar from 'dome/layout/toolbars' ;
import Dispatch from 'dome/layout/dispatch' ;
import Form from 'dome/layout/forms' ;
import Ivette from '@ivette' ;
import Project from './Project' ;

// --------------------------------------------------------------------------
// --- Configuration View
// --------------------------------------------------------------------------

export default function Configure()
{

  const [ state, setState ] = Project.useState();
  const configure = state.configure ;
  if (!configure) return null;

  const { module, value, error, modified=false, copied } = configure ;
  const valueId = value && value.id ;
  const savedId = module && module.id ;
  const isFresh = Ivette.isFresh(valueId);
  const borrowed_label = copied && module.label ;
  const borrowed_title = copied && module.title ;

  const validIdent = (id) =>
        id === savedId ||
        (!Ivette.isValid(id) ? 'Invalid identifier (not a filename)' :
         !Ivette.isFresh(id) ? 'Already used identifier' :
         true) ;

  const validLabel = borrowed_label && ((label) => label !== borrowed_label) ;
  const validTitle = borrowed_title && ((title) => title !== borrowed_title) ;

  const onChange = (value,error) => {
    Object.assign( configure, { modified: true, value, error } );
    setState({ configure });
  };

  const onReload = () => {
    setState({ configure: {
      module,
      copied: configure.copied,
      value: Project.initConfigValue(configure.module)
    }});
  };

  const closeWith = (current) => {
    setState({
      current,
      configure: undefined,
      frame: configure.onClose || 'home'
    });
  };

  const onClose = () => closeWith( state.current );

  const onApply = () => {
    if ( value && !error && !module.locked()) {
      let commit = Ivette.commitModule( module, value );
      module.synchronize(commit)
        .catch(onError)
        .finally(() => closeWith( configure.copied ? module : undefined ));
    } else {
      closeWith( undefined );
    }
  };

  const onError = (err) => Dialogs.showMessageBox({
    kind: 'warning',
    title: 'Module Management Error',
    message: 'An error occurs during a module operation:\n' + err,
    buttons: [{ label:'Ok' }]
  });

  const onRemove = () => Dialogs.showMessageBox({
    kind: 'warning',
    title: 'Remove Module',
    message: 'Definitively remove this Module from your Project ?',
    defaultValue: false,
    cancelValue: false,
    buttons: [
      { value:false, label:'No' },
      { value:true,  label:'Remove' }
    ]
  }).then( (ok) => {
    if (ok) {
      let removal = Ivette.removeModule( configure.module );
      module.synchronize(removal)
        .catch(onError)
        .finally(() => closeWith( undefined ));
    }
  });

  return (
    <Box.Vfill>
      <Dispatch.Item id='ivette.toolbar.configure'>
        <Toolbar.Separator/>
        <Toolbar.Button
          kind='positive' icon='CHECK'
          label='Apply' title='Apply modifications'
          enabled={modified || isFresh}
          disabled={error || module.locked()}
          onClick={onApply} />
        <Toolbar.Inset/>
        <Label>{ isFresh && 'New' } Module Configuration </Label>
        <Toolbar.Filler/>
        <Toolbar.Button
          kind='negative' icon='TRASH'
          label='Remove' title='Remove module'
          disabled={isFresh}
          enabled={valueId === savedId}
          onClick={onRemove} />
        <Toolbar.Button
          icon='RELOAD' title='Reset configuration'
          enabled={modified}
          onClick={onReload} />
        <Toolbar.Button
          kind='cancel'
          icon='CIRC.CLOSE' title='Cancel modifications'
          onClick={onClose} />
      </Dispatch.Item>
      <Form.Form
        value={value}
        error={error}
        onChange={onChange} >
        <Form.FieldCode
          path='id' label='Module'
          validate={validIdent}
          placeholder={valueId} />
        <Form.FieldText
          path='label' label='Display Name'
          validate={validLabel} />
        <Form.FieldTextArea
          path='title' label='Description'
          validate={validTitle} rows={3} />
        <Form.Select path='config'>
          <Catch label='Plugin Config'>{ module.renderConfig() }</Catch>
        </Form.Select>
      </Form.Form>
    </Box.Vfill>
  );
}

// --------------------------------------------------------------------------
