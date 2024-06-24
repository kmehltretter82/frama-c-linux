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

import * as Forms from 'dome/layout/forms';

export type KeyVal<A> = {[key: string]: A}

export interface buttonFieldInfo {
  value: boolean,
  label: string,
}

export type ButtonList = KeyVal<buttonFieldInfo>

export interface OptionsButtonProps {
  name: string,
  label: string,
  fieldState: Forms.FieldState<KeyVal<boolean>>,
}

export type RadioList = KeyVal<string>

export interface RadioFieldListProps {
  classeName?: string;
  state: Forms.FieldState<string>;
  values: RadioList;
  fieldProps: Forms.GenericFieldProps;
}

export interface ButtonFieldListProps {
  classeName?: string;
  state: Forms.FieldState<KeyVal<boolean>>;
  fieldProps: Forms.GenericFieldProps;
}

export type fieldsName =
  "precision" |
  "main" |
  "libEntry" |
  "domains" |
  "iLevel" |
  "WideningDelay" |
  "ArrayPrecisionLevel" |
  "LinearLevel" |
  "EqualityCall" |
  "OctagonCall" |
  "sLevel" |
  "MinLoopUnroll" |
  "AutoLoopUnroll" |
  "HistoryPartitioning" |
  "SplitReturn" |
  "AllocReturnsNull" |
  "WarnPointerComparison"

export interface EvaField {
  label: string,
  step?: number,
  min?: number,
  max?: number,
  optionRadio?: KeyVal<string>,
  /* eslint-disable-next-line @typescript-eslint/no-explicit-any */
  state: Forms.FieldState<any>
}

export type EvaFormProps =  {[key in fieldsName]: EvaField};

/* ************************************************************************ *
 * Option Eva Forms
 * ************************************************************************ */
export const fieldsPrecisionDependent: fieldsName[] = [
  "MinLoopUnroll",
  "AutoLoopUnroll",
  "WideningDelay",
  "HistoryPartitioning",
  "sLevel",
  "iLevel",
  "ArrayPrecisionLevel",
  "LinearLevel",
  "domains",
  "SplitReturn",
  "EqualityCall",
  "OctagonCall"
];

export const fieldsAlwaysVisible:fieldsName[] = [
  "precision",
  "main",
  "libEntry",
  "domains",
  "sLevel",
  "iLevel",
  "AutoLoopUnroll",
  "SplitReturn",
  "AllocReturnsNull",
  "WarnPointerComparison",
];

export const formEvaDomains: KeyVal<boolean> = {
  'equality': false,
  'symbolic-locations': false,
  'octagon': false,
  'gauges': false,
  'cvalue': false,
};
export const formEvaSplitReturn: KeyVal<string> = {
  '': 'None',
  'full': 'Full',
  'auto': 'Auto'
};

export const formEvaPointerComparison: KeyVal<string> = {
  '': 'None',
  'pointer': 'Pointer',
  'all': 'All'
};

export const formEvaEqualityCall: KeyVal<string> = {
  'none': 'None',
  'formals': 'Formals',
  'all': 'All'
};

export const domainsToKeyVal = (value: string[]): KeyVal<boolean> => {
  const domains = { ...formEvaDomains };
  for (const domain of value) { domains[domain] = true; }
  return domains;
};

export const KeyValToDomains = (value: KeyVal<boolean>):string[] => {
  return Object.entries(value).reduce(function (acc: string[], cur) {
    if(cur[1]) acc.push(cur[0]);
    return acc;
  }, []);
};

export function buttonListEquality(
  a: KeyVal<boolean>, b: KeyVal<boolean>
): boolean {
  const _a = Object.entries(a);
  const _b = Object.entries(b);

  if(_a.length !== _b.length) return false;
  for (const [aKey, aValue] of _a.values()) {
    const bProperty = _b.find(([bkey, ]) => bkey === aKey);
    if(bProperty === undefined) return false;

    const [, bValue] = bProperty;
    if(aValue !== bValue) return false;
  }
  return true;
}

export function domainsEquality(
  a: string[], b: string[]
): boolean {
  return buttonListEquality(
    domainsToKeyVal(a),
    domainsToKeyVal(b)
  );
}
