/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2021                                                */
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

// React & Dome
import React from 'react';
import * as Ivette from 'ivette';
import { Vfill } from 'dome/layout/boxes';
import * as States from 'frama-c/states';
import * as Eva from 'frama-c/api/plugins/eva/general';

function percent(reachable: number, total: number): string {
  return (reachable * 100 / total).toFixed(1) + '%';
}

function FunCoverage(data: Eva.statistics): JSX.Element {
  const {coverage: {functions: {reachable, dead}}} = data;
  const total = reachable + dead;
  const ratio = percent(reachable, total);
  return total > 0 ? (
    <>
      <span>{reachable}</span> function{total === 1 ? '' : 's'} {' '}
      analyzed (out of <span>{total}</span>): <span>{ratio}</span> coverage.
    </>
  ) :
    <>No function to be analyzed.</>;
}

function StmtCoverage(data: Eva.statistics): JSX.Element {
  const {coverage: {statements: {reachable, dead}}} = data;
  const total = reachable + dead;
  const ratio = percent(reachable, total);
  const functions = data.coverage.functions.reachable;
  return (functions > 0 && total > 0 ? (
    <>
      In {functions > 1 ? 'these functions' : 'this function'},{' '}
      <span>{reachable}</span> statements reached
      (out of <span>{total}</span>): <span>{ratio}</span> coverage.
    </>
  ) :
    <></>
  );
}

function CoverageTable(data: Eva.statistics): JSX.Element {
  const {coverage: {functions, statements}} = data;
  const functionsTotal = functions.reachable + functions.dead;
  const statementsTotal = statements.reachable + statements.dead;
  return (
    <table>
      <thead>
        <tr>
          <th />
          <th>Analyzed</th>
          <th>Total</th>
          <th>Coverage</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Functions</td>
          <td>{functions.reachable}</td>
          <td>{functionsTotal}</td>
          <td>{percent(functions.reachable, functionsTotal)}</td>
        </tr>
        <tr>
          <td>Statements</td>
          <td>{statements.reachable}</td>
          <td>{statementsTotal}</td>
          <td>{percent(statements.reachable, statementsTotal)}</td>
        </tr>
      </tbody>
    </table>
  );
}

function plural(count: number): string {
  return count === 1 ? '' : 's';
}

function Errors(data: Eva.statistics): JSX.Element {
  const {eva_events: eva, kernel_events: kernel} = data;
  const total = eva.warnings + eva.errors + kernel.warnings + kernel.errors;
  return (total > 0 ? (
    <>
      Some errors and warnings have been raised during the analysis:
      <table>
        <tbody>
          <tr>
            <td>by the Eva analyzer</td>
            <td>{eva.errors} error{plural(eva.errors)}</td>
            <td>{eva.warnings} warning{plural(eva.warnings)}</td>
          </tr>
          <tr>
            <td>by the Frama-C kernel</td>
            <td>{kernel.errors} error{plural(kernel.errors)}</td>
            <td>{kernel.warnings} warning{plural(kernel.warnings)}</td>
          </tr>
        </tbody>
      </table>
    </>
  ) :
    <>No errors or warnings raised during the analysis.</>
  );
}

function Alarms(data: Eva.statistics,
    categories: Map<string, States.Tag>): JSX.Element {
  const {alarms, statuses: {alarms: {invalid, unknown}}} = data;
  const total = unknown + invalid;

  const label = (category: Eva.alarmCategory): string | undefined =>
    categories.get(category)?.descr;

  return (
    <>
      <div>{total} alarms{plural(total)} generated by the analysis</div>
      <table>
        <tbody>
          {alarms.map(entry => (
            <tr key={entry.category}>
              <td>{entry.count}</td>
              <td>{label(entry.category)}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {invalid > 0 && (
      <div>
        {invalid} of them {invalid === 1 ? 'is a' : 'are'} sure
        alarm{plural(invalid)}.
      </div>
      )}
    </>
  );
}

function Statuses(data: Eva.statistics): JSX.Element {
  const { assertions, preconds } = data.statuses;
  const all = (entry: Eva.statusesEntry): number =>
    entry.valid + entry.unknown + entry.invalid;
  const totalAssertions = all(assertions);
  const totalPreconds = all(preconds);
  const total = totalAssertions + totalPreconds;
  const proven = assertions.valid + preconds.valid;
  if (total > 0) {
    return (
      <>
        <table>
          <tbody>
            <tr>
              <th>Assertions</th>
              <td>{assertions.valid} valid</td>
              <td>{assertions.unknown} unknown</td>
              <td>{assertions.invalid} invalid</td>
              <td>{totalAssertions} total</td>
            </tr>
            <tr>
              <th>Preconditions</th>
              <td>{preconds.valid} valid</td>
              <td>{preconds.unknown} unknown</td>
              <td>{preconds.invalid} invalid</td>
              <td>{totalPreconds} total</td>
            </tr>
          </tbody>
        </table>
        {percent(proven, total)} of the logical properties reached have been
        proven.
      </>
    );
  }

  return (<>No logical properties have been reached by the analysis.</>);

}

export function EvaSummary(): JSX.Element {
  const alarmCategories = States.useTags(Eva.alarmCategoryTags);
  const data = States.useSyncValue(Eva.stats);

  return (data && alarmCategories ? (
    <>
      <h2>Coverage</h2>
      <ul>
        <li>{FunCoverage(data)}</li>
        <li>{StmtCoverage(data)}</li>
      </ul>
      {CoverageTable(data)}
      <h2>Errors</h2>
      {Errors(data)}
      <h2>Alarms</h2>
      {Alarms(data, alarmCategories)}
      <h2>Statuses</h2>
      {Statuses(data)}
    </>
  ) :
    <></>
  );
}

function EvaSummaryComponent(): JSX.Element {
  return (
    <>
      <Ivette.TitleBar />
      <Vfill>
        <EvaSummary />
      </Vfill>
    </>
  );
}

Ivette.registerComponent({
  id: 'frama-c.plugins.eva_summary',
  group: 'frama-c.plugins',
  rank: 10,
  label: 'Eva Summary',
  title: 'Summary of the Eva analysis',
  children: <EvaSummaryComponent />,
});

// --------------------------------------------------------------------------
