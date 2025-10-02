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
import { Section, SidebarTitle } from 'dome/frame/sidebars';
import { LSplit } from 'dome/layout/splitters';
import { classes } from 'dome/misc/utils';
import { Vfill } from 'dome/layout/boxes';
import { LED } from 'dome/controls/displays';

import * as Server from 'frama-c/server';
import * as Params from 'frama-c/kernel/api/parameters';

import { SelectedPlugins, usePluginsContextById } from '.';
import { State, useServerField, useSyncValue } from '../states';
import { Remote } from './actions';


// --------------------------------------------------------------------------
// --------------------------------------------------------------------------

export type recordRemotes = Record<string, Forms.BufferController>;
export type recordRemotesState = [
  recordRemotes,
  (id: string, remote:Forms.BufferController) => void
];

export type FieldType = boolean | string | number;

interface Option<FieldType> {
  /** Option ID */
  id?: string;
  /** label */
  label: string;
  /** description for tooltip */
  title?: string;
  /** option state */
  state: Forms.FieldState<FieldType>;
  /** default value */
  default: FieldType;
}

export interface BoolOption extends Option<boolean> {
  // labelButton?: {on: string, off: string};
}

export interface StringOption extends Option<string> {
  choices?: Record<string, string>;
  multiple?: boolean;
}

// TODO : Add float

 export interface NumberOption extends Option<number> {
  min?: number;
  max?: number;
}

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

function useIsSet(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  formId: string, sectionId: string, id: string, stateFC: State<any>
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
        // eslint-disable-next-line no-console
        console.warn("Error :", id, err);
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

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function isState(s: State<any>, params: Params.parameter): boolean {
  // eslint-disable-next-line no-console
  if(!s) console.warn(`${params.name} : ${params.state} : ${params.type}`);
  return !!s;
}

function getActions<A>(
  state: Forms.FieldState<A>,
  equal?: (a: A, b: A) => boolean,
): JSX.Element | undefined {
  if(!state) return undefined;
  return (
    <Forms.Actions>
      <Forms.ResetButton state={state} title="Reset" equal={equal} />
      <Forms.CommitButton state={state} title="Apply" equal={equal} />
    </Forms.Actions>
  );
}

function getClasses<A>(
  state: Forms.FieldState<A>,
  name: string,
  isSet: boolean,
): string | undefined {
  return classes(
    "field"+name,
    !Forms.isStable(state) && "options-field-modified",
    isSet && 'field-is-set',
  );
}

function BoolField(props: FieldProps)
: React.JSX.Element | null {
  const { formId, sectionId, param, remote } = props;
  const { name, help, state } = param;
  const sBool = Params[state as keyof typeof Params] as State<boolean>;
  const isSet = useIsSet(formId, sectionId, name, sBool);
  const vState = useField(remote, sBool, false);

  if(!vState || !isState(sBool, param)) return null;
  return <Forms.Field
      className={isSet ? 'field-is-set' : undefined}
      label={name}
      title={help}
      actions={getActions(vState)}
      >
      <div className={getClasses(vState, name, isSet)} />
      <Forms.ButtonField
        label={vState.value ? "Enabled" : "disabled"}
        state={vState}
        />
    </Forms.Field>;
}

function NumberField(props: FieldProps)
: React.JSX.Element | null {
  const { formId, sectionId, param, remote } = props;
  const { name, help, state, range } = props.param;
  const sNumb = Params[state as keyof typeof Params] as State<number>;
  const isSet = useIsSet(formId, sectionId, name, sNumb);
  const vState = useField(remote, sNumb, 0);

  let min = 0;
  let max = 100000;
  let step = 1;
  if(!vState || !isState(sNumb, param)) return null;
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
      className={getClasses(vState, name, isSet)}
      actions={getActions(vState)}
    />;
}

function StringField(props: FieldProps)
: React.JSX.Element | null {
  const { formId, sectionId, param, remote } = props;
  const { name, help, state } = param;
  const sStr = Params[state as keyof typeof Params] as State<string>;
  const isSet = useIsSet(formId, sectionId, name, sStr);
  const vState = useField(remote, sStr, '');

  if(!vState || !isState(sStr, param)) return null;
  return <Forms.TextField
      label={name}
      placeholder='value'
      title={help}
      state={vState as Forms.FieldState<string | undefined>}
      latency={100}
      className={getClasses(vState, name, isSet)}
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

export type SectionParams = [string, Params.parameter[]];
interface FormSectionProps {
  id: string;
  label: string;
  params: Params.parameter[];
  remote: Forms.BufferController;
}

function FormSection(props: FormSectionProps): React.JSX.Element {
  const { id, label, params, remote } = props;
  const sectionId = `${id}-${label}`;
  const { isSetElement } = usePluginsContextById(id);
  const fieldsSorted = React.useMemo(() =>
    params.sort((a, b) => alpha(a.name, b.name)), [params]);

  const fields = fieldsSorted.map((param) => getField({
    formId: id, sectionId: sectionId, param, remote
  }));

  if(!label) return <>{fields}</>;
  return<Section key={sectionId}
      label={label}
      defaultUnfold={false}
      summary={isSetElement[sectionId] ? <LED status='active'/> : undefined}
      settings={`form-section-${sectionId}-fold`}
    >{fields}</Section>;
}

interface FormProps {
  id: string;
  style?: React.CSSProperties;
  remotesState: recordRemotesState;
}

function Form(props: FormProps): React.JSX.Element {
  const { id, style, remotesState } = props;
  const { params } = usePluginsContextById(id);
  const remote = useRemote(id, remotesState);

  return (
    <Vfill style={style}>
      <SidebarTitle label={id}><Remote remote={remote} /></SidebarTitle>
      <Forms.SidebarForm style={{ overflowY: 'auto' }}>
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

interface FormsProps {
  plugins: Params.plugin[];
  selectedState: [
    SelectedPlugins,
    React.Dispatch<React.SetStateAction<SelectedPlugins>>
  ];
  remotesState: recordRemotesState;
}

export function OptionsForms(props: FormsProps): React.JSX.Element {
  const { selectedState, remotesState } = props;
  const [ [left, right], ] = selectedState;

  return (
    <div className='framac-options-forms'>
      <AliveScope>
        <LSplit settings="frama.c.options.forms" unfold={true}>
          <KeepAlive key={left} id={left}>
            <Form id={left} remotesState={remotesState} />
          </KeepAlive>
          <KeepAlive key={right} id={right}>
            <Form id={right} remotesState={remotesState} />
          </KeepAlive>
        </LSplit>
      </AliveScope>
    </div>
  );
}
