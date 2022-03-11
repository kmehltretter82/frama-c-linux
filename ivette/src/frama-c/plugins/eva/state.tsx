import React from 'react';
import * as Dome from 'dome/dome';
import * as States from 'frama-c/states';
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Values from 'frama-c/plugins/eva/api/values';
import { callstack, evaluation } from 'frama-c/plugins/eva/api/values';

import { Icon } from 'dome/controls/icons';
// import { Stmt } from 'frama-c/plugins/eva/valueinfos';
// import { Diff } from 'frama-c/plugins/eva/diffed';
// import { FontSizer, SizedArea } from 'frama-c/plugins/eva/sized';

import * as Ivette from 'ivette';
import { Cell, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Filler, Hpack, Vpack, Vfill } from 'dome/layout/boxes';
import { Inset, Button, ButtonGroup } from 'dome/frame/toolbars';



type Status = 'True' | 'False' | 'Unknown'
type Alarm = [ Status, string ]

export interface Location {
  target: Ast.marker;
  fct: string;
}

interface Info {
  code?: string;
  stmt?: Ast.marker;
  rank?: number;
  effects?: boolean;
  condition?: boolean;
}

interface Values {
  errors?: string;
  vBefore?: evaluation;
  vAfter?: evaluation;
  vThen?: evaluation;
  vElse?: evaluation;
}

function defaultValues(e: any): Values {
  const empty: evaluation = { value: '', alarms: [], pointedVars: [] };
  return { errors: `Error: ${e}`, vBefore: empty };
}

export interface Probe extends Location, Info {
  values: (c?: callstack) => Promise<Values>
}



function getInfo(loc: Location): Info {
  const { target } = loc;
  const [ cache ] = React.useState<Map<Ast.marker, Info>>(new Map());
  if (cache.has(target)) return cache.get(target) as Info;
  const error: Info = { code: '(error)' };
  const request = Server.send(Values.getProbeInfo, target);
  const { result = error } = Dome.usePromise(request.catch(() => error));
  cache.set(target, result);
  return result;
}

export function useProbe(loc: Location): Probe {
  const [ cache ] = React.useState<Map<Location, Probe>>(new Map());
  if (cache.has(loc)) return cache.get(loc) as Probe;
  const info = getInfo(loc);
  const values = async (c?: Values.callstack): Promise<Values> => {
    const req = Server.send(Values.getValues, {...loc, callstack:c });
    return req.catch(defaultValues);
  };
  const result = { ...loc, ...info, values };
  cache.set(loc, result);
  return result;
}



interface StmtProps {
  stmt?: Ast.marker;
  marker: Ast.marker;
  short?: boolean;
}

function Stmt(props: StmtProps): JSX.Element {
  const markersInfo = States.useSyncArray(Ast.markerInfo);
  const { stmt, marker, short } = props;
  if (!stmt) return <></>;
  const line = markersInfo.getData(marker)?.sloc?.line;
  const filename = markersInfo.getData(marker)?.sloc?.base;
  const title = markersInfo.getData(stmt)?.descr;
  const text = short ? `@L${line}` : `@${filename}:${line}`;
  const className = 'dome-text-cell eva-stmt';
  return <span className={className} title={title}>{text}</span>;
}



interface AlarmsInfosProps {
  probe?: Probe;
  callstack?: callstack;
}

function AlarmsInfos(props: AlarmsInfosProps): JSX.Element {
  const { probe, callstack: c } = props;
  if (!probe) return <></>;
  const { result: domain } = Dome.usePromise(probe.values(c));
  const alarms = domain?.vBefore?.alarms ?? [];
  if (alarms.length > 0) {
    const renderAlarm = ([status, alarm]: Alarm) => {
      const className = `eva-alarm-info eva-alarm-${status}`;
      return <Code className={className} icon="WARNING">{alarm}</Code>;
    };
    return (
      <Vpack className="eva-info">
        {React.Children.toArray(alarms.map(renderAlarm))}
      </Vpack>
    );
  }
  return <></>;
}



interface StackInfosProps {
  callstack?: callstack;
}

export interface Callsite {
  callee: string;
  caller?: string;
  stmt?: Ast.marker;
}

function getCallsites(callstack?: callstack): Promise<Callsite[]> {
  if (!callstack) return Promise.resolve([]);
  return Server.send(Values.getCallstackInfo, callstack);
}

function StackInfos(props: StackInfosProps): JSX.Element {
  const [, setSelection] = States.useSelection();
  const { callstack } = props;
  const { result: callsites = [] } = Dome.usePromise(getCallsites(callstack));
  if (callsites.length <= 1) return <></>;
  const makeCallsite = ({ caller, stmt }: Callsite) => {
    if (!caller || !stmt) return null;
    const key = `${caller}@${stmt}`;
    const select = (meta: boolean) => {
      const location = { fct: caller, marker: stmt };
      setSelection({ location });
      if (meta) States.MetaSelection.emit(location);
    };
    const onClick = (evt: React.MouseEvent) => { select(evt.altKey); };
    const onDoubleClick = (evt: React.MouseEvent) => {
      evt.preventDefault();
      select(true);
    };
    return (
      <Cell
        key={key}
        icon='TRIANGLE.LEFT'
        className='eva-callsite'
        onClick={onClick}
        onDoubleClick={onDoubleClick}
      >
        {caller}
        <Stmt stmt={stmt} marker={stmt} />
      </Cell>
    );
  };

  return (
    <Hpack className="eva-info">
      {callsites.map(makeCallsite)}
    </Hpack>
  );
}



interface ProbeInfosProps {
  probe?: Probe;
  removeLoc: (loc: Location) => void;
  display: StateToDisplay;
  setDisplay: (display: StateToDisplay) => void;
}

export function ProbeInfos(props: ProbeInfosProps): JSX.Element {
  const { probe, removeLoc, display, setDisplay } = props;
  if (!probe || !probe.code) return <></>;
  const { code, stmt, target } = probe;
  return (
    <Hpack className="eva-probeinfo">
      <div className="eva-probeinfo-code">
        <div className='eva-sized-area dome-text-cell'>{code}</div>
      </div>
      <Code><Stmt stmt={stmt} marker={target} /></Code>
      <IconButton
        icon="CIRC.CLOSE"
        className="eva-probeinfo-button"
        title="Discard the probe"
        onClick={() => removeLoc(probe)}
      />
      <Filler />
      <ButtonGroup className='eva-probeinfo-state'>
        <Button
          label='B'
          value='Before'
          selected={display === 'Before' || display === 'Both'}
          title='Show values before statement effects'
          onClick={() => {
            if (display === 'Before') setDisplay('None')
            else if (display === 'After') setDisplay('Both')
            else if (display === 'None') setDisplay('Before')
            else if (display === 'Both') setDisplay('After')
          }}
        />
        <Button
          label='A'
          value='After'
          selected={display === 'After' || display === 'Both'}
          title='Show values after statement effects'
          onClick={() => {
            if (display === 'Before') setDisplay('Both')
            else if (display === 'After') setDisplay('None')
            else if (display === 'None') setDisplay('After')
            else if (display === 'Both') setDisplay('Before')
          }}
        />
      </ButtonGroup>
    </Hpack>
  );
  /*
        <Button
          visible={condition}
          label="C"
          selected={vcond === 'Cond'}
          title="Show values in all conditions"
          onClick={() => model.setVcond('Cond')}
        />
        <Button
          visible={condition || vcond === 'Then'}
          selected={vcond === 'Then'}
          enabled={condition}
          label="T"
          value="Then"
          title="Show reduced values when condition holds (Then)"
          onClick={() => model.setVcond('Then')}
        />
        <Button
          visible={condition || vcond === 'Else'}
          selected={vcond === 'Else'}
          enabled={condition}
          label="E"
          value="Else"
          title="Show reduced values when condition does not hold (Else)"
          onClick={() => model.setVcond('Else')}
        />
        <Button
          visible={condition || effects}
          selected={vstmt === 'After'}
          label="A"
          value="After"
          title="Show values after/before statement effects"
          onClick={() => {
            model.setVstmt(vstmt === 'After' ? 'Before' : 'After');
          }}
        />
      </ButtonGroup>
    </Hpack>
  );
  */
}



export type StateToDisplay = 'Before' | 'After' | 'Both' | 'None'

export interface ProbeRenderProps {
  probe: Probe;
  focused: boolean
  display: StateToDisplay;
  selectProbe: () => void;
  removeProbe: () => void;
  addLoc: (loc: Location) => void;
}



export function ProbeHeader(props: ProbeRenderProps): JSX.Element {
  const { probe, focused, display } = props;
  const { code = '(error)', stmt, target } = probe;
  const color = 'eva-probes eva-' + focused ? 'focused' : 'cell';
  const { selectProbe, removeProbe } = props;
  const [, setSelection] = States.useSelection();

  // Computing the number of columns. By design, either vAfter or vThen and
  // vElse are empty. Also by design (hypothesis), it is not function of the
  // considered callstacks, so we check on the consolidated.
  const { result = defaultValues('Unknown')} = Dome.usePromise(probe.values());
  const { vBefore, vAfter, vThen, vElse } = result;
  let colSpan = 0;
  if (display !== 'After' && vBefore) colSpan += 1;
  if (display !== 'Before' && vAfter) colSpan += 1;
  if (display !== 'Before' && vThen && vElse) colSpan += 2;

  const loc: States.SelectionActions = { location: probe };
  const onClick = (): void => { setSelection(loc); selectProbe(); };
  const onContextMenu = (): void => {
    const items: Dome.PopupMenuItem[] = [];
    const removeLabel = `Remove column for ${code}`;
    items.push({ label: removeLabel, onClick: removeProbe });
    Dome.popupMenu(items);
  };
  
  return (
    <th
      className={color}
      colSpan={colSpan}
      onClick={onClick}
      onContextMenu={onContextMenu}
    >
      <span className='dome-text-cell'>{code}</span>
      <Stmt stmt={stmt} marker={target} short={true}/>
    </th>
  );
}



type CallstackElement = (c?: callstack) => JSX.Element

function getAlarmStatus(alarms: Alarm[]): string {
  if (alarms.length === 0) return 'none';
  if (alarms.find(([st, _]) => st === 'False')) return 'False';
  else return 'Unknown';
}

export function ProbeValues(props: ProbeRenderProps): CallstackElement {
  const { probe, display } = props;
  const { selectProbe, addLoc } = props;
  const [, setSelection] = States.useSelection();

  // Building common parts
  const loc: States.SelectionActions = { location: probe };
  const onClick = (): void => { setSelection(loc); selectProbe(); };
  const onContextMenu = (evaluation: Values.evaluation) => (): void => {
    const { value, pointedVars } = evaluation;
    const items: Dome.PopupMenuItem[] = [];
    const copy = () => navigator.clipboard.writeText(value);
    if (value !== '') items.push({ label: 'Copy to clipboard', onClick: copy });
    if (items.length > 0 && pointedVars.length > 0) items.push('separator');
    pointedVars.forEach((lval) => {
      const [text, lvalMarker] = lval;
      const label = `Display values for ${text}`;
      const location = { fct: probe.fct, target: lvalMarker };
      const onItemClick = () => addLoc(location);
      items.push({ label, onClick: onItemClick });
    });
    if (items.length > 0) Dome.popupMenu(items);
  };

  function result(c?: callstack): JSX.Element {
  const { result = defaultValues('Unknown')} = Dome.usePromise(probe.values(c));
  const { vBefore, vAfter, vThen, vElse } = result;
    function td(e: Values.evaluation, state: string): JSX.Element {
      const status = getAlarmStatus(e.alarms);
      const alarmClass = `eva-cell-alarms eva-alarm-${status}`;
      const title = 'At least one alarm is raised in one callstack';
      return (
        <td
          className='eva-values eva-cell'
          onClick={onClick}
          onContextMenu={onContextMenu(e)}
        >
          <Icon className={alarmClass} size={10} title={title} id="WARNING" />
          <span className={`eva-state-${state}`}>{e.value}</span>
        </td>
      );
    }
    if (display === 'Before' && vBefore) return td(vBefore, 'Before');
    if (display === 'After' && vAfter) return td(vAfter, 'After');
    if (display === 'After' && vThen && vElse)
      return <>{td(vThen, 'Then')}{td(vElse, 'Else')}</>;
    if (display === 'Both' && vBefore && vAfter)
      return <>{td(vBefore, 'Before')}{td(vAfter, 'After')}</>;
    if (display === 'Both' && vBefore && vThen && vElse)
      return <>{td(vBefore, 'Before')}{td(vThen, 'Then')}{td(vElse, 'Else')}</>;
    return <></>;
  }

  return result;
}



interface FunctionProps {
  fct: string;
  markers: Set<Ast.marker>;
  display: StateToDisplay;
  close: () => void;
  selectLoc: (loc: Location) => void;
  isSelected: (loc: Location) => boolean;
  removeLoc: (loc: Location) => void;
  addLoc: (loc: Location) => void;
}

interface FunctionTitleProps extends FunctionProps {
  byCallstacks: boolean;
  folded: boolean;
  setFolded: (folded: boolean) => void;
  setByCallstacks: (byCallstack: boolean) => void;
}

function FunctionTitle(props: FunctionTitleProps): JSX.Element {
  const { fct, folded, byCallstacks } = props;
  const { setFolded, setByCallstacks, close } = props;
  return (
    <>
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
    </>
  );
}

function FunctionSection(props: FunctionProps): JSX.Element {
  const { fct, markers, display } = props;
  const [ byCallstacks, setByCallstacks ] = React.useState(false);
  const [ folded, setFolded ] = React.useState(false);

  const reqCallstacks = Server.send(Values.getCallstacks, [...markers]);
  const { result } = Dome.usePromise(reqCallstacks.catch(() => [undefined]));
  const callstacks = byCallstacks ? result ?? [undefined] : [undefined];

  const probes: Set<Probe> = new Set();
  markers.forEach((target) => probes.add(useProbe({ target, fct })));

  let renderProps: ProbeRenderProps[] = [];
  const { isSelected, addLoc } = props;
  probes.forEach((probe) => {
    const focused = isSelected(probe);
    const selectProbe = (): void => props.selectLoc(probe);
    const removeProbe = (): void => props.removeLoc(probe);
    const fcts = { selectProbe, removeProbe, addLoc };
    renderProps.push({ probe, focused, display, ...fcts });
  });

  const headers = renderProps.map(ProbeHeader);
  const values = callstacks.map((callstack) => {
    return renderProps.map((props) => ProbeValues(props)(callstack))
  });

  return (
    <>
      <FunctionTitle
        {...props}
        byCallstacks={byCallstacks}
        setByCallstacks={setByCallstacks}
        folded={folded}
        setFolded={setFolded}
      />
      <table>
        <tr>{headers}</tr>
        {values.map((callstackValues) => <tr>{callstackValues}</tr>)}
      </table>
    </>
  );
}



type Maybe<A> = A | undefined;

export function EvaTable(): JSX.Element {
  const [ display, setDisplay ] = React.useState<StateToDisplay>('Before');
  const [ fcts ] = React.useState<Map<string, Set<Ast.marker>>>(new Map());

  const addLoc = (loc: Location): void => {
    const { fct, target: m } = loc;
    const ms = fcts.get(fct);
    fcts.set(fct, ms ? ms.add(m) : (new Set<Ast.marker>()).add(m));
  };

  const removeLoc = (loc: Location): void => {
    const { fct, target: m } = loc;
    const ms = fcts.get(fct);
    if (ms) ms.delete(m);
  };

  // TODO: Faire descendre setCS pour pouvoir sélectionner les callstacks
  const [ cs, setCS ] = React.useState<Maybe<callstack>>(undefined);

  const [ selected, select ] = React.useState<Maybe<Location>>(undefined);
  const selectedProbe = selected ? useProbe(selected) : undefined;
  const isSelected = (loc: Location): boolean => loc === selected;
  const closeFct = (fct: string): () => void => () => { fcts.delete(fct); };

  let functionsProps: FunctionProps[] = [];
  fcts.forEach((markers, fct) => {
    const selectLoc = select;
    const close = closeFct(fct);
    const calls = { selectLoc, isSelected, removeLoc, addLoc };
    functionsProps.push({ fct, markers, display, close, ...calls });
  });


  return (
    <>
      <Ivette.TitleBar />
      <Vfill>
        <ProbeInfos probe={selectedProbe} removeLoc={removeLoc} />
        <Vfill>{functionsProps.map(FunctionSection)}</Vfill>
        <AlarmsInfos probe={selectedProbe} callstack={cs} />
        <StackInfos callstack={cs}/>
      </Vfill>
    </>
  );
}
