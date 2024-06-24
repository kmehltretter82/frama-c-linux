/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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

// --------------------------------------------------------------------------
// --- Sidebar Selector
// --------------------------------------------------------------------------

import React from 'react';
import * as Forms from 'dome/layout/forms';
import { classes } from 'dome/misc/utils';
import * as Globals from 'frama-c/kernel/Globals';
import * as States from 'frama-c/states';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Eva from 'frama-c/plugins/eva/api/general';
import * as EvaDef from 'frama-c/plugins/eva/EvaDefinitions';

/* -------------------------------------------------------------------------- */
/* --- Eva form section                                                   --- */
/* -------------------------------------------------------------------------- */
function Section(p: Forms.SectionProps): JSX.Element {
  const settings = `ivette.eva.option.${p.label}`;
  return (
    <Forms.Section
      label={p.label}
      unfold
      error={p.error}
      settings={settings}
    >
      {p.children}
    </Forms.Section>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Button/Radio list                                                  --- */
/* -------------------------------------------------------------------------- */
function OptionsButton(props: EvaDef.OptionsButtonProps): JSX.Element {
  const { name, label, fieldState } = props;
  const state = Forms.useProperty(fieldState, name);
  return <Forms.ButtonField label={label} state={state} />;
}

function ButtonFieldList(
  props: EvaDef.ButtonFieldListProps
): JSX.Element {
  const { classeName, state, fieldProps } = props;
  const { value } = state;

  const htmlButtonList = Object.keys(value)
    .map((p) => <OptionsButton
      key={p}
      name={p}
      label={p}
      fieldState={state}
    />);
  return (
    <Forms.Field  {...fieldProps}>
      <div className={classeName}></div>
      {htmlButtonList}
    </Forms.Field>
  );
}

export function RadioFieldList(
  props: EvaDef.RadioFieldListProps
): JSX.Element {
  const { classeName, state, values, fieldProps } = props;
  const htmlRadioList = Object.entries(values)
    .map(([k, v]) => <Forms.RadioField
      key={k}
      label={v}
      value={k}
      state={state}
    />);
  return (
    <Forms.Field  {...fieldProps}>
      <div className={classeName}></div>
      {htmlRadioList}
    </Forms.Field>
  );
}


/** ***************************************************************************
*
******************************************************************************/
interface EvaFormOptionsProps {
  fields: EvaDef.EvaFormProps;
}

function getActions<A>(
  state: Forms.FieldState<A>,
  equal?: (a: A, b: A) => boolean,
): JSX.Element | undefined {
  if(!state) return undefined;
  return (
    <Forms.Actions>
      <Forms.ResetButton
        state={state}
        title="Reset"
        equal={equal}
      />
      <Forms.CommitButton
        state={state}
        title="Commit"
        equal={equal}
      />
    </Forms.Actions>
  );
}

export function EvaFormOptions(
  props: EvaFormOptionsProps
): JSX.Element {
  const { fields } = props;

  const showAllFields = Forms.useState(false);

  const ker = States.useSyncArrayProxy(Ast.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
  const fctsList = React.useMemo(() =>
    Globals.computeFcts(ker, eva)
      .filter((fct) => !fct.extern && !fct.stdlib && !fct.builtin)
      .sort((a, b) => a.name.localeCompare(b.name)),
    [ker, eva]
  );

  function isNoAlwaysVisibleFieldsStable(): boolean {
    let disable = false;
    for (const [name, evaField] of Object.entries(fields)) {
      if (EvaDef.fieldsAlwaysVisible.includes(name as EvaDef.fieldsName)) {
        continue;
      }
      if (!Forms.isStable(evaField.state)) {
        disable = true;
        break;
      }
    }
    return disable;
  }

  function getClasses<A>(
    state: Forms.FieldState<A>,
    name: EvaDef.fieldsName
  ): string | undefined {
    const isDepPrecision = EvaDef.fieldsPrecisionDependent.includes(name);
    const notVisible =
      !showAllFields.value &&
      !EvaDef.fieldsAlwaysVisible.includes(name);
    return classes(
      !Forms.isStable(state) && "eva-field-modified",
      isDepPrecision && "eva-precision-dep",
      notVisible ? "hidden-field" : "visible-field"
    );
  }

  function getSpinnerField(name: EvaDef.fieldsName): JSX.Element {
    const field = fields[name];
    const state = field.state;
    return (
    <Forms.SpinnerField
      label={field.label}
      step={field.step}
      min={field.min as number}
      max={field.max as number}
      state={field.state as Forms.FieldState<number | undefined>}
      className={getClasses(state, name)}
      actions={getActions(state)}
      />
    );
  }

  function getRadioField(name: EvaDef.fieldsName): JSX.Element {
    const field = fields[name];
    const state = field.state;
    return (
      <RadioFieldList
        fieldProps={{
          label: field.label,
          actions: getActions(state)
        }}
        classeName={getClasses(state, name)}
        values={field.optionRadio as EvaDef.RadioList}
        state={field.state}
        />
    );
  }

  function getBooleanField(name: EvaDef.fieldsName): JSX.Element {
    const field = fields[name];
    const state = field.state;
    return (
      <Forms.Field
        label={field.label}
        actions={getActions(state)}
      >
        <div className={getClasses(state, "libEntry")} />
        <Forms.ButtonField
          label={state.value ? "Enabled" : "disabled"}
          state={state}
        />
      </Forms.Field>
    );
  }

  const mainField =
  <Forms.SelectField
    label="Eva main"
    state={fields["main"].state as Forms.FieldState<string | undefined>}
    actions={getActions(fields["main"].state)}
  >
    {
      fctsList.map((f) => <option
          key={f.key} id={f.key} value={f.name}
          className={getClasses(fields["main"].state, "main")}
        >{f.name}</option>
      )
    }
  </Forms.SelectField>;

  const domainsField =
  <ButtonFieldList
    fieldProps={{
      label: "Domains",
      actions: getActions(fields["domains"].state, EvaDef.buttonListEquality)
    }}
    classeName={getClasses(fields["domains"].state, "domains")}
    state={fields["domains"].state}
    />;

  return (
    <Forms.SidebarForm className="eva-form">
      <Forms.CheckboxField
        label={"show all fields"}
        title=
          "disabled if it checked and if the fields to be hidden are not stable"
        state={showAllFields}
        disabled={isNoAlwaysVisibleFieldsStable()}
      />

      {getSpinnerField("precision")}
      {mainField}
      {getBooleanField("libEntry")}

      <Section label="Abstract interpretation" >
          {domainsField}
          {getSpinnerField("iLevel")}
          {getSpinnerField("WideningDelay")}
          {getSpinnerField("ArrayPrecisionLevel")}
          {getSpinnerField("LinearLevel")}
          {getRadioField("EqualityCall")}
          {getBooleanField("OctagonCall")}
      </Section>

      <Section label="State partitioning" >
          {getSpinnerField("sLevel")}
          {getSpinnerField("MinLoopUnroll")}
          {getSpinnerField("AutoLoopUnroll")}
          {getSpinnerField("HistoryPartitioning")}
          {getRadioField("SplitReturn")}
      </Section>

      <Section label="Message" >
        {getBooleanField("AllocReturnsNull")}
        {getRadioField("WarnPointerComparison")}
      </Section>

    </Forms.SidebarForm>
  );
}
