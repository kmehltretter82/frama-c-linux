/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

import React from 'react';
import { AliveScope, KeepAlive } from 'react-activation';

import * as Forms from 'dome/layout/forms';
import { alpha } from 'dome/data/compare';
import { Section } from 'dome/frame/sidebars';
import { LSplit } from 'dome/layout/splitters';
import { classes } from 'dome/misc/utils';
import { Vfill } from 'dome/layout/boxes';
import { Debug } from 'dome/system';

import * as Server from 'frama-c/server';
import * as Params from 'frama-c/kernel/api/parameters';

import { SelectedPlugins, usePluginsContextById } from '.';
import { State, useServerField, useSyncValue } from '../states';
import { Remote } from './actions';

const D = new Debug('OptionsForms');

// --------------------------------------------------------------------------
// --------------------------------------------------------------------------

export type recordRemotes = Record<string, Forms.BufferController>;
export type recordRemotesState = [
  recordRemotes,
  (id: string, remote:Forms.BufferController) => void
];

export function useRemotes(): recordRemotesState {
  const [remotes, setRemotes] = React.useState<recordRemotes>({});

  const set = React.useCallback(
    (id: string, controller: Forms.BufferController): void => {
    setRemotes( prev => ({ ...prev, [id]: controller }));
  }, [setRemotes]);

  return [remotes, set];
}

export function useRemote(
  id: string,
  remotesState: recordRemotesState,
): Forms.BufferController {
  const [ remotes, setRemotes ] = remotesState;
  const remote = Forms.useController(remotes[id]);

  React.useEffect(() => {
    if(!remotes[id]) setRemotes(id, remote);
  }, [remotes, setRemotes, remote, id]);

  return remotes[id];
}

function useField<A>(
  remote: Forms.BufferController,
  state: State<A>,
  defaultValue: A,
): Forms.FieldState<A> {
  const sField = useServerField(state, defaultValue);
  return Forms.useBuffer(remote, sField);
}

function useIsSet<A>(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formId: string, sectionId: string, id: string, stateFC: State<A>
): boolean {
  const { isSetElement, addPluginsSet } = usePluginsContextById(id);
  const state = useSyncValue(stateFC);

  React.useEffect(() => {
    const fetchIsSet = async (id: string): Promise<void> => {
      try {
        const isSet = await Server.send(Params.isSetParameter, id);
        if(isSet) addPluginsSet({
          [formId]: true,
          [sectionId]: true,
          [id]: true });
      } catch (err) {
        D.warn("Error on isSetParameter: ", id, err);
      }
    };
    fetchIsSet(id);
  }, [state, addPluginsSet, formId, sectionId, id]);

  return isSetElement[id];
}

// --------------------------------------------------------------------------
// --- Form and Fields
// --------------------------------------------------------------------------

interface FieldProps {
  formId: string;
  sectionId: string;
  param: Params.parameter;
  remote: Forms.BufferController,
}

function isState<A>(s: State<A>, params: Params.parameter): boolean {
  if(!s) D.warn(`${params.name} : ${params.state} : ${params.type}`);
  return !!s;
}

function getActions<A>(state: Forms.FieldState<A>): JSX.Element | undefined {
  if(!state) return undefined;
  return (
    <Forms.Actions>
      <Forms.ResetButton state={state} title="Reset" />
      <Forms.CommitButton state={state} title="Apply" />
    </Forms.Actions>
  );
}

function getClasses<A>(
  state: Forms.FieldState<A>,
  isSet: boolean,
): string | undefined {
  return classes(
    !Forms.isStable(state) && 'modified',
    isSet && 'field-is-set',
  );
}

function BoolField(props: FieldProps)
: React.JSX.Element | null {
  const { formId, sectionId, param, remote } = props;
  const { name, help, state } = param;
  const sBool = Params[state as keyof typeof Params] as State<boolean>;
  const isSet = useIsSet<boolean>(formId, sectionId, name, sBool);
  const vState = useField(remote, sBool, false);

  if(!vState || !isState<boolean>(sBool, param)) return null;
  return (
    <Forms.Field
      className={getClasses(vState, isSet)}
      label={name}
      title={help}
      actions={getActions(vState)}
    >
      <Forms.ButtonField
        label={vState.value ? "Enabled" : "disabled"}
        state={vState}
        />
    </Forms.Field>
  );
}

function NumberField(props: FieldProps)
: React.JSX.Element | null {
  const { formId, sectionId, param, remote } = props;
  const { name, help, state, range } = props.param;
  const sNumb = Params[state as keyof typeof Params] as State<number>;
  const isSet = useIsSet<number>(formId, sectionId, name, sNumb);
  const vState = useField(remote, sNumb, 0);

  if(!vState || !isState<number>(sNumb, param)) return null;

  /* Arbitrary limits which should always be overwritten by the range below. */
  let min = 0;
  let max = 100000;
  let step = 1;
  if(range && range.length === 2
    && typeof range[0] === "number" && typeof range[1] === "number") {
    min = range[0];
    max = range[1];
    step = Math.round((max - min)*0.1);
  }

  return <Forms.SpinnerField
      label={name}
      title={help}
      step={step < 1000 ? step : 1}
      min={min}
      max={max}
      state={vState as Forms.FieldState<number | undefined>}
      className={getClasses(vState, isSet)}
      actions={getActions(vState)}
    />;
}

function StringField(props: FieldProps)
: React.JSX.Element | null {
  const { formId, sectionId, param, remote } = props;
  const { name, help, state } = param;
  const sStr = Params[state as keyof typeof Params] as State<string>;
  const isSet = useIsSet<string>(formId, sectionId, name, sStr);
  const vState = useField(remote, sStr, '');

  if(!vState || !isState<string>(sStr, param)) return null;
  return <Forms.TextField
      label={name}
      placeholder='value'
      title={help}
      state={vState as Forms.FieldState<string | undefined>}
      latency={100}
      className={getClasses(vState, isSet)}
      actions={getActions(vState)}
    />;
}

function getField(props: FieldProps)
: React.JSX.Element | null {
  const { type, name } = props.param;
  switch(type) {
    case 'Bool': return <BoolField key={name} {...props}></BoolField>;
    case 'Int': return <NumberField key={name} {...props}></NumberField>;
    case 'String': return <StringField key={name} {...props}></StringField>;
    default: return null;
  }
}

interface FormSectionProps {
  id: string;
  label: string;
  params: Params.parameter[];
  remote: Forms.BufferController;
}

function FormSection(props: FormSectionProps): React.JSX.Element {
  const { id, label, params, remote } = props;
  const sectionId = `${id}-${label}`;
  const fieldsSorted = React.useMemo(() =>
    params.sort((a, b) => alpha(a.name, b.name)), [params]);

  const fields = fieldsSorted.map((param) => getField({
    formId: id, sectionId: sectionId, param, remote
  }));

  if(!label) return <>{fields}</>;
  return<Section key={sectionId}
      label={label}
      defaultUnfold={false}
      settings={`form-section-${sectionId}-fold`}
    >{fields}</Section>;
}

interface FormProps {
  id: string;
  remotesState: recordRemotesState;
}

function Form(props: FormProps): React.JSX.Element {
  const { id, remotesState } = props;
  const { params } = usePluginsContextById(id);
  const remote = useRemote(id, remotesState);
  const titleBar = <Forms.FormTitle label={id}>
      <Remote remote={remote} />
    </Forms.FormTitle>;

  return (
    <Vfill>
      <Forms.SidebarForm titleBar={titleBar} >
        { params.map(s =>
          <FormSection key={s[0]} label={s[0]} params={s[1]} id={id}
            remote={remote}
          /> )}
      </Forms.SidebarForm>
    </Vfill>
  );
}

// --------------------------------------------------------------------------
// --- Forms
// --------------------------------------------------------------------------

interface OptionsFormsProps {
  selectedState: [
    SelectedPlugins,
    React.Dispatch<React.SetStateAction<SelectedPlugins>>
  ];
  remotesState: recordRemotesState;
}

export function OptionsForms(props: OptionsFormsProps): React.JSX.Element {
  const { selectedState, remotesState } = props;
  const [ [left, right], ] = selectedState;

  return (
    <div className='framac-options-forms'>
      <AliveScope>
        <LSplit settings="frama.c.options.forms" unfold={true}>
          <KeepAlive cacheKey={left}>
            <Form id={left} remotesState={remotesState} />
          </KeepAlive>
          { right === '' ?
              <div style={{
                width: '100%',
                height: '100%',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                fontSize: '1.2em'
              }}>
                Select the form by left-clicking on it in the sidebar.
              </div>
            :
              <KeepAlive cacheKey={right}>
                <Form id={right} remotesState={remotesState} />
              </KeepAlive>
          }
        </LSplit>
      </AliveScope>
    </div>
  );
}
