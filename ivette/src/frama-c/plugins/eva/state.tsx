import React from 'react';
import * as Ivette from 'ivette';
import * as Dome from 'dome/dome';
import * as States from 'frama-c/states';
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Values from 'frama-c/plugins/eva/api/values';
import { callstack, evaluation } from 'frama-c/plugins/eva/api/values';

import { Icon } from 'dome/controls/icons';
import { Cell, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Filler, Hpack, Vpack, Vfill } from 'dome/layout/boxes';
import { Inset, Button, ButtonGroup } from 'dome/frame/toolbars';



type Maybe<A> = A | undefined;
type Alarm = [ Status, string ]
type Status = 'True' | 'False' | 'Unknown'
type StateToDisplay = 'Before' | 'After' | 'Both' | 'None'

function getAlarmStatus(alarms: Alarm[]): string {
  if (alarms.length === 0) return 'none';
  if (alarms.find(([st, _]) => st === 'False')) return 'False';
  else return 'Unknown';
}

class CacheManager<K, V> {

  private readonly request: (key: K) => Promise<V>;
  private readonly cache: Map<K, V>;

  constructor(request: (key: K) => Promise<V>) {
    console.log('Coucou');
    this.request = request;
    this.cache = new Map<K, V>()
    this.request = this.request.bind(this);
    this.get = this.get.bind(this);
    this.clear = this.clear.bind(this);
  }

  get(key: K): Maybe<V> {
    const add = (value: V): void => { this.cache.set(key, value); };
    if (!this.cache.has(key)) this.request(key).then(add);
    return this.cache.get(key);
  }

  clear(): void {
    this.cache.clear();
  }

}



interface FunctionInfos {
  markers: Set<Ast.marker>;
  byCallstacks: boolean;
  folded: boolean;
}

class FunctionsManager {

  private readonly cache = new Map<string, FunctionInfos>();

  newFunction(fct: string): void {
    const markers = new Set<Ast.marker>();
    const folded = false;
    const byCallstacks = false;
    this.cache.set(fct, { markers, byCallstacks, folded });
  }

  getInfos(fct: string): Maybe<FunctionInfos> {
    return this.cache.get(fct);
  }

  setByCallstacks(fct: string, byCallstacks: boolean): void {
    const infos = this.getInfos(fct); if (!infos) return;
    const { markers, folded } = infos;
    this.cache.set(fct, { markers, byCallstacks, folded });
  }

  setFolded(fct: string, folded: boolean): void {
    const infos = this.getInfos(fct); if (!infos) return;
    const { markers, byCallstacks } = infos;
    this.cache.set(fct, { markers, byCallstacks, folded });
  }

  addLocation(loc: Location): void {
    const { target, fct } = loc;
    const infos = this.getInfos(fct);
    if (!infos) {
      this.newFunction(fct);
      this.addLocation(loc);
    }
    else {
      infos.markers.add(target);
    }
  }

  removeLocation(loc: Location): void {
    const { target, fct } = loc;
    this.getInfos(fct)?.markers.delete(target);
  }

  delete(fct: string): void {
    this.cache.delete(fct);
  }

  clear(): void {
    this.cache.clear();
  }

  map<A>(func: (infos: FunctionInfos, fct: string) => A): A[] {
    const acc: A[] = [];
    this.cache.forEach((infos, fct) => acc.push(func(infos, fct)));
    return acc;
  }

}



interface Callsite {
  callee: string;
  caller?: string;
  stmt?: Ast.marker;
}

function requestCallsites(callstack?: callstack): Promise<Callsite[]> {
  if (!callstack) return Promise.resolve([]);
  return Server.send(Values.getCallstackInfo, callstack);
}



export interface Location {
  target: Ast.marker;
  fct: string;
}

interface Infos {
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

interface Probe extends Location, Infos, Values {}

interface ProbeProps {
  loc: Location;
  callstack?: callstack;
}

async function requestProbe(props: ProbeProps): Promise<Probe> {
  const { loc, callstack } = props;
  const infos = await Server.send(Values.getProbeInfo, loc.target);
  const values = await Server.send(Values.getValues, { ...loc, callstack });
  return { ...loc, ...infos, ...values };
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

function AlarmsInfos(props: { probe?: Probe }): JSX.Element {
  const alarms = props.probe?.vBefore?.alarms ?? [];
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
  callsites: Callsite[];
  setSelection: (a: States.SelectionActions) => void;
}

function StackInfos(props: StackInfosProps): JSX.Element {
  const { callsites, setSelection } = props;
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
  console.log(props);
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
}



interface ProbeRenderProps {
  probe: Probe;
  focused: boolean;
  display: StateToDisplay;
  selectProbe: () => void;
  removeProbe: () => void;
  addLoc: (loc: Location) => void;
  setSelection: (a: States.SelectionActions) => void;
}

function ProbeHeader(props: ProbeRenderProps): JSX.Element {
  const { probe, focused, display, setSelection } = props;
  const { code = '(error)', stmt, target } = probe;
  const color = 'eva-probes eva-' + focused ? 'focused' : 'cell';
  const { selectProbe, removeProbe } = props;

  // Computing the number of columns. By design, either vAfter or vThen and
  // vElse are empty. Also by design (hypothesis), it is not function of the
  // considered callstacks, so we check on the consolidated.
  const { vBefore, vAfter, vThen, vElse } = probe;
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

function ProbeValues(props: ProbeRenderProps): JSX.Element {
  const { probe, display } = props;
  const { selectProbe, addLoc, setSelection } = props;

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

  const { vBefore, vAfter, vThen, vElse } = probe;
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


interface FunctionProps {
  fct: string;
  markers: Set<Ast.marker>;
  display: StateToDisplay;
  close: () => void;
  getProbe: (props: ProbeProps) => Maybe<Probe>;
  selectLoc: (loc: Location) => void;
  isSelected: (loc: Location) => boolean;
  removeLoc: (loc: Location) => void;
  addLoc: (loc: Location) => void;
  folded: boolean;
  setFolded: (folded: boolean) => void;
  byCallstacks: boolean;
  getCallstacks: (markers: Set<Ast.marker>) => Maybe<callstack[]>;
  setByCallstacks: (byCallstack: boolean) => void;
  selectCallstack: (callstack: callstack) => void;
  isSelectedCallstack: (callstack: callstack) => boolean;
  setSelection: (a: States.SelectionActions) => void;
}

function FunctionTitle(props: FunctionProps): JSX.Element {
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
  const { byCallstacks, setByCallstacks } = props;
  const { folded, setFolded, setSelection } = props;
  const { isSelected, addLoc, getCallstacks: getCS } = props;
  const callstacks = byCallstacks ? getCS(markers) ?? [undefined] : [undefined];

  const renderProps: ProbeRenderProps[][] = callstacks.map((callstack) => {
    let acc: ProbeRenderProps[] = [];
    markers.forEach((target) => {
      const probe = props.getProbe({ loc: { target, fct }, callstack });
      if (!probe) return;
      const focused = isSelected(probe);
      const selectProbe = (): void => props.selectLoc(probe);
      const removeProbe = (): void => props.removeLoc(probe);
      const fcts = { selectProbe, removeProbe, addLoc };
      acc.push({ probe, focused, display, ...fcts, setSelection });
    });
    return acc;
  });

  const headers = renderProps[0].map(ProbeHeader);
  const values = renderProps.map((t) => t.map(ProbeValues));

  return (
    <div key={fct}>
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
    </div>
  );
}




function requestCallstacks(markers: Set<Ast.marker>): Promise<callstack[]> {
  let markersList: Ast.marker[] = [];
  markers.forEach((marker) => markersList.push(marker));
  return Server.send(Values.getCallstacks, markersList);
}

export function EvaTable(): JSX.Element {
  const [selection, setSelection ] = States.useSelection();
  const [ fcts ] = React.useState(new FunctionsManager());
  const [ probes ] = React.useState(() => new CacheManager(requestProbe));
  const [ callsites ] = React.useState(new CacheManager(requestCallsites));
  const [ callstacks ] = React.useState(new CacheManager(requestCallstacks));
  const [ display, setDisplay ] = React.useState<StateToDisplay>('Before');
  const [ loc, selectLoc ] = React.useState<Maybe<Location>>(undefined);
  const [ cs, setCS ] = React.useState<Maybe<callstack>>(undefined);
  const isSelected = (l: Location) => l === loc;
  const isSelectedCallstack = (c: callstack) => c === cs;
  const selectedProbe = loc ? probes.get({ loc, callstack: cs }) : undefined;

  React.useEffect(() => {
    const { current: loc } = selection;
    if (!loc) { selectLoc(undefined); return; }
    const { fct, marker } = loc;
    if (!fct || !marker) { selectLoc(undefined); return; }
    fcts.addLocation({ target: marker, fct });
    console.log('Location:');
    console.log(loc);
    selectLoc({ target: marker, fct });
  }, [selection]);

  const functionsProps: FunctionProps[] = fcts.map((infos, fct) => {
    const { markers, byCallstacks, folded } = infos;
    const setFolded = (folded: boolean) => fcts.setFolded(fct, folded);
    const setByCallstacks = (byCS: boolean) => fcts.setByCallstacks(fct, byCS);
    return {
      fct,
      markers,
      display,
      close: () => fcts.delete(fct),
      getProbe: probes.get,
      selectLoc,
      isSelected,
      removeLoc: fcts.removeLocation,
      addLoc: fcts.addLocation,
      folded,
      setFolded,
      byCallstacks,
      getCallstacks: callstacks.get,
      setByCallstacks,
      selectCallstack: setCS,
      isSelectedCallstack,
      setSelection
    };
  });

  return (
    <>
      <Ivette.TitleBar />
      <Vfill>
        <ProbeInfos
          probe={selectedProbe}
          removeLoc={fcts.removeLocation}
          display={display}
          setDisplay={setDisplay}
        />
        {functionsProps.map(FunctionSection)}
        <AlarmsInfos probe={selectedProbe} />
        <StackInfos
          callsites={callsites.get(cs) ?? []}
          setSelection={setSelection}
        />
      </Vfill>
    </>
  );
}
