/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2022                                                */
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

import React from 'react';
import * as Ivette from 'ivette';
import * as Dome from 'dome/dome';
import * as States from 'frama-c/states';
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Values from 'frama-c/plugins/eva/api/values';
import ControlPoint from 'frama-c/plugins/eva/ControlPoint';

import { classes } from 'dome/misc/utils';
import { Icon } from 'dome/controls/icons';
import { Cell, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Filler, Hpack, Vpack } from 'dome/layout/boxes';
import { Inset, Button, ButtonGroup } from 'dome/frame/toolbars';



type Request<A, B> = (a: A) => Promise<B>;
type StateToDisplay = 'Before' | 'After' | 'Both' | 'None'
type callstack = 'Summary' | Values.callstack

function useCallstacksCache(): Request<Ast.marker[], callstack[]> {
  const get = React.useCallback((markers) => {
    return Server.send(Values.getCallstacks, markers);
  }, []);
  const toString = React.useCallback((markers: Ast.marker[]) => {
    return markers.map((m) => `${m}`).join('|');
  }, []);
  return Dome.useCache(get, toString);
}

type Alarm = [ 'True' | 'False' | 'Unknown', string ]
function getAlarmStatus(alarms: Alarm[] | undefined): string {
  if (!alarms) return 'none';
  if (alarms.length === 0) return 'none';
  if (alarms.find(([st, _]) => st === 'False')) return 'False';
  else return 'Unknown';
}

type MarkerTracked = [ 'Tracked', boolean ]
type MarkerPinned  = [ 'Pinned' , boolean ]
type MarkerStatus  = MarkerTracked | MarkerPinned | 'JustFocused'

function MarkerStatusClass(status: MarkerStatus): string {
  if (status === 'JustFocused') return 'eva-header-just-focused';
  const [ kind, focused ] = status;
  return 'eva-header-' + kind.toLowerCase() + (focused ? '-focused' : '');
}

function isPinnedMarker(status: MarkerStatus): boolean {
  if (status === 'JustFocused') return false;
  const [ kind ] = status;
  return kind === 'Pinned';
}



interface Callsite {
  callee: string;
  caller?: string;
  stmt?: Ast.marker;
}

function useCallsitesCache(): Request<callstack, Callsite[]> {
  const get = React.useCallback((c) => {
    if (c !== 'Summary') return Server.send(Values.getCallstackInfo, c);
    else return Promise.resolve([]);
  }, []);
  return Dome.useCache(get);
}

interface CallsiteCellProps {
  callstack: callstack | 'Header';
  index?: number;
  getCallsites: Request<callstack, Callsite[]>;
  selectedClass?: string;
}

function makeStackTitle(calls: Callsite[]): string {
  const cs = calls.slice(1);
  if (cs.length > 0)
    return `Callstack: ${cs.map((c) => c.callee).join(' \u2190 ')}`;
  return 'Callstack Details';
}

async function CallsiteCell(props: CallsiteCellProps): Promise<JSX.Element> {
  const { callstack: c, index, getCallsites, selectedClass = '' } = props;
  const callClass = classes('eva-table-callsite-box', selectedClass);
  const callsites = c !== 'Header' ? await getCallsites(c) : [];
  const infos =
    c === 'Header' ? 'Corresponding callstack' :
      c === 'Summary' ? 'Summary' : makeStackTitle(callsites);
  return (
    <td className={callClass} title={infos}>
      {c === 'Header' ? '#' : c === 'Summary' ? '∑' : index}
    </td>
  );
}



interface Location {
  target: Ast.marker;
  fct: string;
}

interface Evaluation {
  errors?: string;
  vBefore?: Values.evaluation;
  vAfter?: Values.evaluation;
  vThen?: Values.evaluation;
  vElse?: Values.evaluation;
}

interface Probe extends Location {
  code?: string;
  stmt?: Ast.marker;
  rank?: number;
  effects?: boolean;
  condition?: boolean;
  evaluate: Request<callstack, Evaluation>
}

function useProbeCache(): Request<Location, Probe> {
  const toString = React.useCallback((l) => `${l.fct}:${l.target}`, []);
  const get = React.useCallback(async (loc: Location): Promise<Probe> => {
    const infos = await Server.send(Values.getProbeInfo, loc.target);
    const evaluate: Request<callstack, Evaluation> = (c) => {
      const callstack = c === 'Summary' ? undefined : c as Values.callstack;
      return Server.send(Values.getValues, { ...loc, callstack });
    };
    return { ...loc, ...infos, evaluate };
  }, []);
  return Dome.useCache(get, toString);
}



interface StmtProps {
  stmt?: Ast.marker;
  marker?: Ast.marker;
  short?: boolean;
}

function Stmt(props: StmtProps): JSX.Element {
  const markersInfo = States.useSyncArray(Ast.markerInfo);
  const { stmt, marker, short } = props;
  if (!stmt || !marker) return <></>;
  const line = markersInfo.getData(marker)?.sloc?.line;
  const filename = markersInfo.getData(marker)?.sloc?.base;
  const title = markersInfo.getData(stmt)?.descr;
  const text = short ? `@L${line}` : `@${filename}:${line}`;
  const className = 'dome-text-cell eva-stmt';
  return <span className={className} title={title}>{text}</span>;
}



function AlarmsInfos(probe?: Probe): Request<callstack, JSX.Element> {
  return async (c: callstack): Promise<JSX.Element> => {
    const evaluation = await probe?.evaluate(c);
    const alarms = evaluation?.vBefore?.alarms ?? [];
    if (alarms.length <= 0) return <></>;
    const renderAlarm = ([status, alarm]: Alarm): JSX.Element => {
      const className = classes('eva-alarm-info', `eva-alarm-${status}`);
      return <Code className={className} icon="WARNING">{alarm}</Code>;
    };
    const children = React.Children.toArray(alarms.map(renderAlarm));
    return <Vpack className="eva-info">{children}</Vpack>;
  };
}



interface StackInfosProps {
  callsites: Callsite[];
  isSelected: boolean;
  setSelection: (a: States.SelectionActions) => void;
}

async function StackInfos(props: StackInfosProps): Promise<JSX.Element> {
  const { callsites, setSelection, isSelected } = props;
  const selectedClass = isSelected ? 'eva-focused' : '';
  const className = classes('eva-callsite', selectedClass);
  if (callsites.length <= 1) return <></>;
  const makeCallsite = ({ caller, stmt }: Callsite): JSX.Element => {
    if (!caller || !stmt) return <></>;
    const key = `${caller}@${stmt}`;
    const location = { fct: caller, marker: stmt };
    const select = (meta: boolean): void => {
      setSelection({ location });
      if (meta) States.MetaSelection.emit(location);
    };
    const onClick = (evt: React.MouseEvent): void => { select(evt.altKey); };
    const onDoubleClick = (evt: React.MouseEvent): void => {
      evt.preventDefault();
      select(true);
    };
    return (
      <Cell
        key={key}
        icon='TRIANGLE.LEFT'
        className={className}
        onClick={onClick}
        onDoubleClick={onDoubleClick}
      >
        {caller}
        <Stmt stmt={stmt} marker={stmt} />
      </Cell>
    );
  };
  const children = React.Children.toArray(callsites.map(makeCallsite));
  return <Hpack className="eva-info">{children}</Hpack>;
}



interface ProbeInfosProps {
  probe?: Probe;
  status?: MarkerStatus;
  removeProbe: (probe: Probe) => void;
  setLocPin: (loc: Location, pin: boolean) => void;
  state: StateToDisplay;
  setState: (state: StateToDisplay) => void;
}

function SelectedProbeInfos(props: ProbeInfosProps): JSX.Element {
  const { probe, status, setLocPin, removeProbe, state, setState } = props;
  const code = probe?.code;
  const stmt = probe?.stmt;
  const target = probe?.target;
  const visible = code !== undefined;
  const pinned = status ? isPinnedMarker(status) : false;
  return (
    <Hpack className="eva-probeinfo">
      <div
        className="eva-probeinfo-code"
        style={{ visibility: visible ? 'visible' : 'hidden' }}
      >
        <div className='eva-probeinfo-code-text dome-text-cell'>{code}</div>
      </div>
      <Code><Stmt stmt={stmt} marker={target} /></Code>
      <IconButton
        icon='PIN'
        className="eva-probeinfo-button"
        title='Pin the probe'
        selected={pinned}
        visible={visible}
        onClick={() => { if (probe) setLocPin(probe, !pinned); }}
      />
      <IconButton
        icon="CIRC.CLOSE"
        className="eva-probeinfo-button"
        title="Discard the probe"
        onClick={() => { if (probe) removeProbe(probe); }}
        visible={visible}
      />
      <Filler />
      <ButtonGroup className='eva-probeinfo-state'>
        <Button
          value='Before'
          selected={state === 'Before' || state === 'Both'}
          title='Show values before statement effects'
          visible={visible}
          onClick={() => {
            if (state === 'Before') setState('None');
            else if (state === 'After') setState('Both');
            else if (state === 'None') setState('Before');
            else if (state === 'Both') setState('After');
          }}
        >
          <ControlPoint kind={'before'}/>
        </Button>
        <Button
          value='After'
          selected={state === 'After' || state === 'Both'}
          title='Show values after statement effects'
          visible={visible}
          onClick={() => {
            if (state === 'Before') setState('Both');
            else if (state === 'After') setState('None');
            else if (state === 'None') setState('After');
            else if (state === 'Both') setState('Before');
          }}
        >
          <ControlPoint kind={'after'}/>
        </Button>
      </ButtonGroup>
    </Hpack>
  );
}



interface ProbeHeaderProps {
  probe: Probe;
  summary: Evaluation;
  status: MarkerStatus;
  state: StateToDisplay;
  pinProbe: (pin: boolean) => void;
  selectProbe: () => void;
  removeProbe: () => void;
  setSelection: (a: States.SelectionActions) => void;
  locEvt: Dome.Event<Location>;
}

function ProbeHeader(props: ProbeHeaderProps): JSX.Element {
  const { probe, summary, status, state, setSelection, locEvt } = props;
  const { code = '(error)', stmt, target, fct } = probe;
  const color = MarkerStatusClass(status);
  const { selectProbe, removeProbe, pinProbe } = props;

  // Computing the number of columns. By design, either vAfter or vThen and
  // vElse are empty. Also by design (hypothesis), it is not function of the
  // considered callstacks, so we check on the consolidated.
  // const evaluation = await probe.evaluate('Summary');
  const { vBefore, vAfter, vThen, vElse } = summary;
  let span = 0;
  if ((state === 'Before' || state === 'Both') && vBefore) span += 2;
  if ((state === 'After' || state === 'Both') && vAfter) span += 2;
  if ((state === 'After' || state === 'Both') && vThen && vElse) span += 4;
  if (span === 0) return <></>;

  // When the location is selected, we scroll the header into view, making it
  // appears wherever it was.
  const ref = React.createRef<HTMLTableCellElement>();
  locEvt.on((l) => { if (l === probe) ref.current?.scrollIntoView(); });

  const loc: States.SelectionActions = { location: { fct, marker: target} };
  const onClick = (): void => { setSelection(loc); selectProbe(); };
  const onDoubleClick = (): void => pinProbe(!isPinnedMarker(status));
  const onContextMenu = (): void => {
    const items: Dome.PopupMenuItem[] = [];
    const removeLabel = `Remove column for ${code}`;
    items.push({ label: removeLabel, onClick: removeProbe });
    Dome.popupMenu(items);
  };
  
  return (
    <th
      ref={ref}
      className={color}
      colSpan={span}
      onClick={onClick}
      onDoubleClick={onDoubleClick}
      onContextMenu={onContextMenu}
    >
      <span className='dome-text-cell'>{code}</span>
      <Stmt stmt={stmt} marker={target} short={true}/>
    </th>
  );
}



interface ProbeDescrProps {
  summary: Evaluation;
  state: StateToDisplay;
}

function ProbeDescr(props: ProbeDescrProps): JSX.Element[] {
  const { summary, state } = props;
  const { vBefore, vAfter, vThen, vElse } = summary;
  const valuesClass = classes('eva-table-values', 'eva-table-values-center');
  const className = classes(valuesClass, 'eva-table-descrs');
  function td(kind: JSX.Element, colSpan = 1): JSX.Element {
    return <td className={className} colSpan={colSpan + 1}>{kind}</td>;
  }

  const both = (): JSX.Element =>
    <div className='eva-header-after-both'>
      {'After '}
      <div className='eva-stmt'>{'(Then|Else)'}</div>
    </div>;

  const elements: JSX.Element[] = [];
  if (state === 'Before' && vBefore) elements.push(td(<>{'Before'}</>));
  if (state === 'After' && vAfter) elements.push(td(<>{'After'}</>));
  if (state === 'After' && vThen && vElse) {
    elements.push(td(both(), 2));
  }
  if (state === 'Both' && vBefore && vAfter) {
    elements.push(td(<>{'Before'}</>));
    elements.push(td(<>{'After'}</>));
  }
  if (state === 'Both' && vBefore && vThen && vElse) {
    elements.push(td(<>{'Before'}</>));
    elements.push(td(both(), 2));
  }
  return elements;
}



interface ProbeValuesProps {
  probe: Probe;
  summary: Evaluation;
  status: MarkerStatus;
  state: StateToDisplay;
  addLoc: (loc: Location) => void;
  isSelected: boolean;
  summaryOnly: boolean;
}

function ProbeValues(props: ProbeValuesProps): Request<callstack, JSX.Element> {
  const { probe, summary, state, addLoc, isSelected, summaryOnly } = props;
  const summaryStatus = getAlarmStatus(summary.vBefore?.alarms);

  // Building common parts
  const onContextMenu = (evaluation: Values.evaluation) => (): void => {
    const { value, pointedVars } = evaluation;
    const items: Dome.PopupMenuItem[] = [];
    const copy = (): void => { navigator.clipboard.writeText(value); };
    if (value !== '') items.push({ label: 'Copy to clipboard', onClick: copy });
    if (items.length > 0 && pointedVars.length > 0) items.push('separator');
    pointedVars.forEach((lval) => {
      const [text, lvalMarker] = lval;
      const label = `Display values for ${text}`;
      const location = { fct: probe.fct, target: lvalMarker };
      const onItemClick = (): void => addLoc(location);
      items.push({ label, onClick: onItemClick });
    });
    if (items.length > 0) Dome.popupMenu(items);
  };

  return async (callstack: callstack): Promise<JSX.Element> => {
    const evaluation = await probe.evaluate(callstack);
    const { vBefore, vAfter, vThen, vElse } = evaluation;
    const selected = isSelected && callstack !== 'Summary' ? 'eva-focused' : '';
    const font = summaryOnly && callstack === 'Summary' ? 'eva-italic' : '';
    const className = classes('eva-table-values', selected, font);
    function td(e: Values.evaluation): JSX.Element {
      const status = getAlarmStatus(e.alarms);
      const alarmClass = classes('eva-cell-alarms', `eva-alarm-${status}`);
      const kind = callstack === 'Summary' ? 'one' : 'this';
      const title = `At least one alarm is raised in ${kind} callstack`;
      const align = e.value.includes('\n') ? 'left' : 'center';
      const alignClass = `eva-table-values-${align}`;
      const width = summaryStatus !== 'none' ? 'eva-table-values-alarms' : '';
      const c = classes(className, alignClass, width);
      return (
        <>
          <td className={c} onContextMenu={onContextMenu(e)}>
            <span >{e.value}</span>
          </td>
          <td className={classes('eva-table-alarm', selected)}>
            <Icon className={alarmClass} size={10} title={title} id="WARNING" />
          </td>
        </>
      );
    }
    if (state === 'Before' && vBefore) return td(vBefore);
    if (state === 'After' && vAfter) return td(vAfter);
    if (state === 'After' && vThen && vElse)
      return <>{td(vThen)}{td(vElse)}</>;
    if (state === 'Both' && vBefore && vAfter)
      return <>{td(vBefore)}{td(vAfter)}</>;
    if (state === 'Both' && vBefore && vThen && vElse)
      return <>{td(vBefore)}{td(vThen)}{td(vElse)}</>;
    return <></>;
  };
}



interface FunctionProps {
  fct: string;
  markers: Map<Ast.marker, MarkerStatus>;
  state: StateToDisplay;
  close: () => void;
  getProbe: Request<Location, Probe>;
  pinProbe: (probe: Probe, pin: boolean) => void;
  selectProbe: (probe: Probe) => void;
  removeProbe: (probe: Probe) => void;
  addLoc: (loc: Location) => void;
  folded: boolean;
  setFolded: (folded: boolean) => void;
  getCallsites: Request<callstack, Callsite[]>;
  byCallstacks: boolean;
  getCallstacks: Request<Ast.marker[], callstack[]>;
  setByCallstacks: (byCallstack: boolean) => void;
  selectCallstack: (callstack: callstack) => void;
  isSelectedCallstack: (c: callstack) => boolean;
  setSelection: (a: States.SelectionActions) => void;
  locEvt: Dome.Event<Location>;
}

async function FunctionSection(props: FunctionProps): Promise<JSX.Element> {
  const { fct, state, folded, isSelectedCallstack, locEvt } = props;
  const { byCallstacks, setSelection, getCallsites } = props;
  const { addLoc, getCallstacks: getCS } = props;
  const { setFolded, setByCallstacks, close } = props;
  const displayTable = folded ? 'none' : 'table';
  const headerCall = await CallsiteCell({ getCallsites, callstack: 'Header' });

  /* Compute relevant callstacks */
  const markers = Array.from(props.markers.keys());
  const callstacks = byCallstacks ? (await getCS(markers) ?? []) : [];
  const summaryOnly = callstacks.length === 1;

  interface Data { probe: Probe; summary: Evaluation; status: MarkerStatus }
  const entries = Array.from(props.markers.entries());
  const probes = await Promise.all(entries.map(async ([ target, status ]) => {
    const probe = await props.getProbe({ target, fct });
    const summary = await probe.evaluate('Summary');
    return { probe, summary, status } as Data;
  }));

  const headers = await Promise.all(probes.map((d: Data) => {
    const pinProbe = (pin: boolean): void => props.pinProbe(d.probe, pin);
    const selectProbe = (): void => props.selectProbe(d.probe);
    const removeProbe = (): void => props.removeProbe(d.probe);
    const fcts = { selectProbe, pinProbe, removeProbe, setSelection };
    return ProbeHeader({ ...d, state, ...fcts, locEvt });
  }));

  const title = 'Column description';
  const descrs = probes.map((d) => ProbeDescr({ ...d, state }));

  const onClick = (c: callstack): () => void => () => props.selectCallstack(c); 
  function build(d: Data, c: callstack): Promise<JSX.Element> {
    const isSelected = isSelectedCallstack(c);
    const valuesProps = { ...d, state, addLoc, isSelected, summaryOnly };
    return ProbeValues(valuesProps)(c);
  }

  const summary = await Promise.all(probes.map((d) => build(d, 'Summary')));
  const summCall = await CallsiteCell({ callstack: 'Summary', getCallsites });
  const values = await Promise.all(callstacks.map(async (callstack, n) => {
    if (summaryOnly) return <></>;
    const isSelected = isSelectedCallstack(callstack);
    const selector = isSelected && callstack !== 'Summary';
    const selectedClass = selector ? 'eva-focused' : '';
    const callProps = { selectedClass, getCallsites };
    const call = await CallsiteCell({ index: n + 1, callstack, ...callProps });
    const values = await Promise.all(probes.map((d) => build(d, callstack)));
    return (
      <tr key={callstack} onClick={onClick(callstack)}>{call}
        {React.Children.toArray(values)}
      </tr>
    );
  }));

  return (
    <>
      <Hpack className="eva-function">
        <IconButton
          className="eva-fct-fold"
          icon={folded ? 'ANGLE.RIGHT' : 'ANGLE.DOWN'}
          onClick={() => setFolded(!folded)}
        />
        <Cell className="eva-fct-name">{fct}</Cell>
        <Filler />
        <IconButton
          icon="ITEMS.LIST"
          className="eva-probeinfo-button"
          selected={byCallstacks}
          title="Details by callstack"
          onClick={() => setByCallstacks(!byCallstacks)}
        />
        <Inset />
        <IconButton
          icon="CROSS"
          className="eva-probeinfo-button"
          title="Close"
          onClick={close}
        />
      </Hpack>
      <div className='eva-table-container'>
        <table className='eva-table' style={{ display: displayTable }}>
          <tbody>
            <tr>
              {headerCall}
              {React.Children.toArray(headers)}
            </tr>
            <tr>
              <td className='eva-table-callsite-box' title={title}>{'D'}</td>
              {React.Children.toArray(descrs.flat())}
            </tr>
            <tr key={'Summary'} onClick={onClick('Summary')}>
              {summCall}
              {React.Children.toArray(summary)}
            </tr>
            {React.Children.toArray(values)}
          </tbody>
        </table>
      </div>
    </>
  );
}



class FunctionInfos {

  readonly fct: string;
  readonly pinned = new Set<Ast.marker>();
  readonly tracked = new Set<Ast.marker>();
  byCallstacks = false;
  folded = false;

  constructor(fct: string) {
    this.fct = fct;
  }

  has(marker: Ast.marker): boolean {
    const pinned = this.pinned.has(marker);
    const tracked = this.tracked.has(marker);
    return pinned || tracked;
  }

  pin(marker: Ast.marker): void {
    this.pinned.add(marker);
    this.tracked.delete(marker);
  }

  track(marker: Ast.marker): void {
    this.tracked.add(marker);
    this.pinned.delete(marker);
  }

  delete(marker: Ast.marker): void {
    this.pinned.delete(marker);
    this.tracked.delete(marker);
  }

  isEmpty(): boolean {
    return this.pinned.size === 0 && this.tracked.size === 0;
  }

  markers(focusedLoc?: Location): Map<Ast.marker, MarkerStatus> {
    const { target: tgt, fct } = focusedLoc ?? {};
    const inFct = fct !== undefined && fct === this.fct;
    const ms = new Map<Ast.marker, MarkerStatus>();
    this.pinned.forEach((p) => ms.set(p, [ 'Pinned', inFct && tgt === p ]));
    this.tracked.forEach((p) => ms.set(p, [ 'Tracked', inFct && tgt === p ]));
    if (inFct && tgt && !this.has(tgt)) ms.set(tgt, 'JustFocused');
    return new Map(Array.from(ms.entries()).reverse());
  }

}



class FunctionsManager {

  private readonly cache = new Map<string, FunctionInfos>();

  constructor() {
    this.newFunction = this.newFunction.bind(this);
    this.getInfos = this.getInfos.bind(this);
    this.setByCallstacks = this.setByCallstacks.bind(this);
    this.setFolded = this.setFolded.bind(this);
    this.pin = this.pin.bind(this);
    this.track = this.track.bind(this);
    this.removeLocation = this.removeLocation.bind(this);
    this.delete = this.delete.bind(this);
    this.clear = this.clear.bind(this);
    this.map = this.map.bind(this);
  }

  newFunction(fct: string): void {
    if (!this.cache.has(fct)) this.cache.set(fct, new FunctionInfos(fct));
  }

  private getInfos(fct: string): FunctionInfos {
    const { cache } = this;
    if (cache.has(fct)) return cache.get(fct) as FunctionInfos;
    const infos = new FunctionInfos(fct);
    this.cache.set(fct, infos);
    return infos;
  }

  setByCallstacks(fct: string, byCallstacks: boolean): void {
    const infos = this.cache.get(fct);
    if (!infos) return;
    infos.byCallstacks = byCallstacks;
  }

  setFolded(fct: string, folded: boolean): void {
    const infos = this.cache.get(fct);
    if (!infos) return;
    infos.folded = folded;
  }

  pin(loc: Location): void {
    const { target, fct } = loc;
    this.getInfos(fct).pin(target);
  }

  unpin(loc: Location): void {
    const { target, fct } = loc;
    this.cache.get(fct)?.pinned.delete(target);
  }

  track(loc: Location): void {
    const { target, fct } = loc;
    this.getInfos(fct).track(target);
  }

  status(loc?: Location): MarkerStatus | undefined {
    if (!loc) return undefined;
    const infos = this.cache.get(loc.fct);
    if (infos?.pinned.has(loc.target))
      return [ 'Pinned', true ];
    else if (infos?.tracked.has(loc.target))
      return [ 'Tracked', true ];
    return 'JustFocused';
  }

  removeLocation(loc: Location): void {
    const { target, fct } = loc;
    const infos = this.cache.get(fct);
    if (!infos) return;
    infos.delete(target);
  }

  delete(fct: string): void {
    this.cache.delete(fct);
  }

  clear(): void {
    this.cache.clear();
  }

  clean(focused?: Location): void {
    const focusedFct = focused?.fct;
    this.cache.forEach((infos) => {
      if (focusedFct !== infos.fct && infos.isEmpty())
        this.cache.delete(infos.fct);
    });
  }

  map<A>(func: (infos: FunctionInfos, fct: string) => A): A[] {
    const entries = Array.from(this.cache.entries());
    return entries.map(([ fct, infos ]) => func(infos, fct));
  }

}



function EvaTable(): JSX.Element {
  const [ selection, select ] = States.useSelection();
  const [ state, setState ] = React.useState<StateToDisplay>('After');
  const [ cs, setCS ] = React.useState<callstack>('Summary');
  const [ fcts ] = React.useState(new FunctionsManager());
  const [ tac, setTic ] = React.useState(false);
  const [ locEvt ] = React.useState(new Dome.Event<Location>('eva-location'));

  const getProbe = useProbeCache();
  const getCallsites = useCallsitesCache();
  const getCallstacks = useCallstacksCache();

  const [ focus, setFocus ] = React.useState<Probe | undefined>(undefined);
  React.useEffect(() => {
    const target = selection?.current?.marker;
    const fct = selection?.current?.fct;
    const loc = (target && fct) ? { target, fct } : undefined;
    const f = (p: Probe): void => { if (fct && p.code) fcts.newFunction(fct); };
    const update = (p: Probe): void => { f(p) ; setFocus(p); locEvt.emit(p); };
    fcts.clean(loc);
    if (loc) getProbe(loc).then(update);
    else setFocus(undefined);
  }, [ fcts, selection, getProbe, setFocus, locEvt ]);

  const setLocPin = React.useCallback((loc: Location, pin: boolean): void => {
    if (pin) fcts.pin(loc);
    else fcts.unpin(loc);
    setTic(!tac);
  }, [fcts, setTic, tac]);

  const remove = React.useCallback((probe: Probe): void => {
    fcts.removeLocation(probe);
    if (probe.target === focus?.target)
      setFocus(undefined);
    fcts.clean(undefined);
    setTic(!tac);
  }, [ fcts, focus, setFocus, tac ]);

  const functionsPromise = React.useMemo(() => {
    const ps = fcts.map((infos, fct) => {
      const { byCallstacks, folded } = infos;
      const isSelectedCallstack = (c: callstack): boolean => c === cs;
      const setFolded = (folded: boolean): void => {
        fcts.setFolded(fct, folded);
        setTic(!tac);
      };
      const setByCS = (byCS: boolean): void => {
        fcts.setByCallstacks(fct, byCS);
        setTic(!tac);
      };
      return {
        fct,
        markers: infos.markers(focus),
        state,
        close: () => { fcts.delete(fct); setTic(!tac); },
        pinProbe: setLocPin,
        getProbe,
        selectProbe: setFocus,
        removeProbe: remove,
        addLoc: (loc: Location) => { fcts.pin(loc); setTic(!tac); },
        folded,
        setFolded,
        getCallsites,
        byCallstacks,
        getCallstacks,
        setByCallstacks: setByCS,
        selectCallstack: (c: callstack) => { setCS(c); setTic(!tac); },
        isSelectedCallstack,
        setSelection: select,
        locEvt,
      };
    });
    return Promise.all(ps.map(FunctionSection));
  },
  [ cs, fcts, focus, tac, getCallsites, setLocPin,
    getCallstacks, getProbe, remove, select, state, locEvt
  ]);
  const { result: functions } = Dome.usePromise(functionsPromise);

  const alarmsProm = React.useMemo(() => AlarmsInfos(focus)(cs), [ focus, cs ]);
  const { result: alarmsInfos } = Dome.usePromise(alarmsProm);

  const stackInfosPromise = React.useMemo(async () => {
    const callsites = await getCallsites(cs);
    const tgt = selection.current?.marker;
    const p = (c: Callsite): boolean => c.stmt !== undefined && c.stmt === tgt;
    const isSelected = callsites.find(p) !== undefined;
    return StackInfos({ callsites, isSelected, setSelection: select });
  }, [ cs, select, getCallsites, selection ]);
  const { result: stackInfos } = Dome.usePromise(stackInfosPromise);

  return (
    <>
      <Ivette.TitleBar />
      <SelectedProbeInfos
        probe={focus}
        status={fcts.status(focus)}
        setLocPin={setLocPin}
        removeProbe={remove}
        state={state}
        setState={setState}
      />
      <div className='eva-functions-section'>
        {React.Children.toArray(functions)}
      </div>
      {alarmsInfos}
      {stackInfos}
    </>
  );
}



Ivette.registerComponent({
  id: 'frama-c.plugins.values',
  group: 'frama-c.plugins',
  rank: 1,
  label: 'Eva Values',
  title: 'Values inferred by the Eva analysis',
  children: <EvaTable />,
});
