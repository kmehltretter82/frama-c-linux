import React from 'react';
import * as Ivette from 'ivette';
import * as Dome from 'dome/dome';
import * as States from 'frama-c/states';
import * as Server from 'frama-c/server';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Values from 'frama-c/plugins/eva/api/values';
import { callstack, evaluation } from 'frama-c/plugins/eva/api/values';

import { classes } from 'dome/misc/utils';
import { Icon } from 'dome/controls/icons';
import { Cell, Code } from 'dome/controls/labels';
import { IconButton } from 'dome/controls/buttons';
import { Filler, Hpack, Vpack, Vfill } from 'dome/layout/boxes';
import { Inset, Button, ButtonGroup } from 'dome/frame/toolbars';



type Maybe<A> = A | undefined;
type Alarm = [ Status, string ]
type Status = 'True' | 'False' | 'Unknown'
type StateToDisplay = 'Before' | 'After' | 'Both' | 'None'


type MarkerTracked = [ 'Tracked', boolean ]
type MarkerPinned  = [ 'Pinned' , boolean ]
type MarkerStatus  = MarkerTracked | MarkerPinned | 'JustFocused'

function getAlarmStatus(alarms: Alarm[]): string {
  if (alarms.length === 0) return 'none';
  if (alarms.find(([st, _]) => st === 'False')) return 'False';
  else return 'Unknown';
}



interface CacheManagerProps<K, V> {
  request: (key: K) => Promise<V>;
  toString: (key: K) => string;
  name: string;
}

class CacheManager<K, V> {

  readonly request: (key: K) => Promise<V>;
  private readonly toString: (key: K) => string;
  private readonly cache = new Map<string, V>();
  readonly updated: Dome.Event<void>;

  constructor(props: CacheManagerProps<K, V>) {
    const { request, toString, name } = props;
    this.request = request;
    this.request = this.request.bind(this);
    this.toString = toString;
    this.toString = this.toString.bind(this);
    this.get = this.get.bind(this);
    this.clear = this.clear.bind(this);
    this.updated = new Dome.Event(`cache-manager-${name}`);
  }

  get(key: K): Maybe<V> {
    const id = this.toString(key);
    const add = (value: V): void => {
      if (!this.cache.has(id)) {
        this.cache.set(id, value);
        this.updated.emit();
      }
    };
    if (!this.cache.has(id))
      this.request(key).then(add);
    return this.cache.get(id);
  }

  clear(): void {
    this.cache.clear();
  }

}



interface Callsite {
  callee: string;
  caller?: string;
  stmt?: Ast.marker;
}

function CallsitesManager(): CacheManager<Maybe<callstack>, Callsite[]> {
  function request(callstack?: callstack): Promise<Callsite[]> {
    if (!callstack) return Promise.resolve([]);
    return Server.send(Values.getCallstackInfo, callstack);
  }
  const toString = (callstack?: callstack): string => `callstack:${callstack}`;
  const props = { request, toString, name: 'callsites' };
  const [ manager ] = React.useState(new CacheManager(props));
  return manager;
}



export interface Location {
  target: Ast.marker;
  fct: string;
}

interface Probe extends Location {
  code?: string;
  stmt?: Ast.marker;
  rank?: number;
  effects?: boolean;
  condition?: boolean;
  errors?: string;
  vBefore?: evaluation;
  vAfter?: evaluation;
  vThen?: evaluation;
  vElse?: evaluation;
}

interface ProbeProps {
  loc: Location;
  callstack?: callstack;
}

function ProbesManager(): CacheManager<ProbeProps, Probe>{
  async function request(props: ProbeProps): Promise<Probe> {
    const { loc, callstack } = props;
    const infos = await Server.send(Values.getProbeInfo, loc.target);
    const values = await Server.send(Values.getValues, { ...loc, callstack });
    return { ...loc, ...infos, ...values };
  };
  const LocationToString = (loc: Location) => {
    const { target, fct } = loc;
    return `target:${target}|fct:${fct}`;
  };
  const toString = (props: ProbeProps): string => {
    return `${LocationToString(props.loc)}|callstack:${props.callstack}`;
  };
  const props = { request, toString, name: 'probes' };
  const [ manager ] = React.useState(new CacheManager(props));
  return manager;
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

function AlarmsInfos(props: { probe?: Probe }): JSX.Element {
  const alarms = props.probe?.vBefore?.alarms ?? [];
  if (alarms.length <= 0) return <></>;
  const renderAlarm = ([status, alarm]: Alarm) => {
    const className = `eva-alarm-info eva-alarm-${status}`;
    return <Code className={className} icon="WARNING">{alarm}</Code>;
  };
  const children = React.Children.toArray(alarms.map(renderAlarm));
  return <Vpack className="eva-info">{children}</Vpack>;
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
    const location = { fct: caller, marker: stmt };
    const select = (meta: boolean) => {
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
  return <Hpack className="eva-info">{callsites.map(makeCallsite)}</Hpack>;
}

interface ProbeInfosProps {
  probe?: Probe;
  status: Maybe<MarkerStatus>;
  removeLoc: (loc: Location) => void;
  setLocPin: (loc: Location, pin: boolean) => void;
  display: StateToDisplay;
  setDisplay: (display: StateToDisplay) => void;
}

export function ProbeInfos(props: ProbeInfosProps): JSX.Element {
  const { probe, status, setLocPin, removeLoc, display, setDisplay } = props;
  const code = probe?.code;
  const stmt = probe?.stmt;
  const target = probe?.target;
  let pinned = false;
  if (status && status !== 'JustFocused') {
    const [ kind ] = status;
    pinned = kind === 'Pinned';
  }

  return (
    <Hpack className="eva-probeinfo">
      <div
        className="eva-probeinfo-code"
        style={{ visibility: probe !== undefined ? 'visible' : 'hidden' }}
      >
        <div className='eva-sized-area dome-text-cell'>{code}</div>
      </div>
      <Code><Stmt stmt={stmt} marker={target} /></Code>
      <IconButton
        icon='PIN'
        className="eva-probeinfo-button"
        title='Pin the probe'
        selected={pinned}
        visible={probe !== undefined}
        onClick={() => { if (probe) setLocPin(probe, !pinned); }}
      />
      <IconButton
        icon="CIRC.CLOSE"
        className="eva-probeinfo-button"
        title="Discard the probe"
        onClick={() => { if (probe) removeLoc(probe); }}
        visible={probe !== undefined}
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



function MarkerStatusClass(status: MarkerStatus): string {
  if (status === 'JustFocused') return 'eva-header-just-focused';
  const [ kind, focused ] = status;
  return 'eva-header-' + kind.toLowerCase() + (focused ? '-focused' : '');
}

interface ProbeRenderProps {
  probe: Probe;
  status: MarkerStatus;
  display: StateToDisplay;
  selectProbe: () => void;
  removeProbe: () => void;
  selectCallstack: () => void;
  addLoc: (loc: Location) => void;
  setSelection: (a: States.SelectionActions) => void;
}

function ProbeHeader(props: ProbeRenderProps): JSX.Element {
  const { probe, status, display, setSelection } = props;
  const { code = '(error)', stmt, target, fct } = probe;
  const color = MarkerStatusClass(status);
  const { selectProbe, removeProbe } = props;

  // Computing the number of columns. By design, either vAfter or vThen and
  // vElse are empty. Also by design (hypothesis), it is not function of the
  // considered callstacks, so we check on the consolidated.
  const { vBefore, vAfter, vThen, vElse } = probe;
  let span = 0;
  if ((display === 'Before' || display === 'Both') && vBefore) span += 1;
  if ((display === 'After' || display === 'Both') && vAfter) span += 1;
  if ((display === 'After' || display == 'Both') && vThen && vElse) span += 2;
  if (span === 0) return <></>;

  const loc: States.SelectionActions = { location: { fct, marker: target} };
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
      colSpan={span}
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
  const { selectCallstack, addLoc } = props;

  // Building common parts
  const onClick = selectCallstack;
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
    const alarmClass = `eva-alarms eva-alarm-${status}`;
    const title = 'At least one alarm is raised in one callstack';
    return (
      <td
        onClick={onClick}
        className='eva-table-values'
        onContextMenu={onContextMenu(e)}
      >
        <div style={{ position: 'relative' }}>
          <span className={`eva-state-${state}`}>{e.value}</span>
          <Icon className={alarmClass} size={10} title={title} id="WARNING" />
        </div>
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



interface CallsiteCellProps {
  byCallstacks: boolean;
  display: StateToDisplay;
  index?: number;
}

function CallsiteCell(props: CallsiteCellProps): JSX.Element {
  const { byCallstacks, display, index:n } = props;
  const activeClass = byCallstacks ? 'eva-table-callsite-active' : '';
  const callClass = classes('eva-table-callsite', activeClass);
  const callVisibility = display === 'None' ? 'hidden' : 'visible';
  return (
    <td className={callClass} style={{ visibility: callVisibility }}>
      {byCallstacks ? (n !== undefined ? (n === 0 ? '∑' : n) : '#') : ''}
    </td>
  );
}

interface FunctionProps {
  fct: string;
  markers: Map<Ast.marker, MarkerStatus>;
  display: StateToDisplay;
  close: () => void;
  getProbe: (props: ProbeProps) => Maybe<Probe>;
  selectLoc: (loc: Location) => void;
  removeLoc: (loc: Location) => void;
  addLoc: (loc: Location) => void;
  folded: boolean;
  setFolded: (folded: boolean) => void;
  byCallstacks: boolean;
  getCallstacks: (markers: Ast.marker[]) => Maybe<callstack[]>;
  setByCallstacks: (byCallstack: boolean) => void;
  selectCallstack: (callstack?: callstack) => void;
  isSelectedCallstack: (callstack: callstack) => boolean;
  setSelection: (a: States.SelectionActions) => void;
}

function FunctionTitle(props: FunctionProps): JSX.Element {
  const { fct, folded, byCallstacks } = props;
  const { setFolded, setByCallstacks, close } = props;
  return (
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
  );
}

function FunctionSection(props: FunctionProps): JSX.Element {
  const { fct, markers, display, folded } = props;
  const { byCallstacks, setSelection } = props;
  const { selectLoc, removeLoc } = props;
  const { addLoc, getCallstacks: getCS } = props;
  let callstacks: (callstack | undefined)[] = [undefined];
  let markersArray: Ast.marker[] = [];
  markers.forEach((_, marker) => markersArray.push(marker));
  if (byCallstacks) callstacks = callstacks.concat(getCS(markersArray) ?? []);

  const renderProps: ProbeRenderProps[][] = callstacks.map((callstack) => {
    let acc: ProbeRenderProps[] = [];
    markers.forEach((status, target) => {
      const probe = props.getProbe({ loc: { target, fct }, callstack });
      if (!probe) return;
      const selectProbe = (): void => selectLoc(probe);
      const removeProbe = (): void => removeLoc(probe);
      const selectCallstack = (): void => props.selectCallstack(callstack);
      const fcts = { selectProbe, removeProbe, addLoc, selectCallstack };
      acc.push({ probe, status, display, ...fcts, setSelection });
    });
    return acc;
  });

  const headers = renderProps[0].map(ProbeHeader);
  const values = renderProps.map((t) => t.map(ProbeValues));
  const displayTable = folded ? 'none' : 'table';
  const callsiteProps = { byCallstacks, display };
  const valuesRows = values.map((callstackValues, index) => {
    const callsite = <CallsiteCell {...callsiteProps} index={index} />;
    return <tr>{callsite}{callstackValues}</tr>;
  });

  return (
    <div>
      <FunctionTitle {...props} />
      <table className='eva-table' style={{ display: displayTable }}>
        <tbody>
          <tr><CallsiteCell {...callsiteProps} />{headers}</tr>
          {React.Children.toArray(valuesRows)}
        </tbody>
      </table>
    </div>
  );
}



class FunctionInfos {

  readonly fct: string;
  readonly pinned = new Set<Ast.marker>();
  readonly tracked = new Set<Ast.marker>();
  byCallstacks: boolean = false;
  folded: boolean = false;

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
    this.tracked.delete(marker)
  }

  isEmpty(): boolean {
    return this.pinned.size === 0 && this.tracked.size === 0;
  }

  markers(focusedLoc?: Location): Map<Ast.marker, MarkerStatus> {
    const focused = focusedLoc?.target;
    const fct = focusedLoc?.fct;
    const { pinned, tracked } = this;
    const markers = new Map<Ast.marker, MarkerStatus>();
    if (fct && focused)
      if (fct === this.fct && !pinned.has(focused) && !tracked.has(focused))
        markers.set(focused, 'JustFocused');
    pinned.forEach((p) => markers.set(p, [ 'Pinned', p === focused ]));
    tracked.forEach((t) => markers.set(t, [ 'Tracked', t === focused ]));
    return markers;
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

  status(loc: Maybe<Location>): Maybe<MarkerStatus> {
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
    const acc: A[] = [];
    this.cache.forEach((infos, fct) => acc.push(func(infos, fct)));
    return acc;
  }

}



function CallstacksManager(): CacheManager<Ast.marker[], callstack[]> {
  function request(markers: Ast.marker[]): Promise<callstack[]> {
    return Server.send(Values.getCallstacks, markers);
  };
  const toString = (markers: Ast.marker[]): string => {
    let str = '';
    markers.forEach((marker) => { str += `|${marker}`; });
    return str;
  };
  const props = { request, toString, name: 'callstacks' };
  const [ manager ] = React.useState(new CacheManager(props));
  return manager;
}



function useForceUpdate(): () => void {
  const [ counter, setCounter ] = React.useState(0);
  return () => { console.log(`update ${counter}`); setCounter(counter + 1); };
}



export function EvaTable(): JSX.Element {
  const [ selection, setSelection ] = States.useSelection();
  const [ display, setDisplay ] = React.useState<StateToDisplay>('Before');

  const forceUpdate = useForceUpdate();
  const probes = ProbesManager();
  const callsites = CallsitesManager();
  const callstacks = CallstacksManager();
  // Dome.useEvent(probes.updated, forceUpdate);
  // Dome.useEvent(callsites.updated, forceUpdate);
  // Dome.useEvent(callstacks.updated, forceUpdate);

  const [ fcts ] = React.useState(new FunctionsManager);

  const [ cs, setCS ] = React.useState<Maybe<callstack>>(undefined);
  const isSelectedCallstack = (c: callstack) => c === cs;

  const [ focus, selectFocus ] = React.useState<Maybe<Location>>(undefined);
  React.useEffect(() => {
    const target = selection?.current?.marker;
    const fct = selection?.current?.fct;
    if (fct) fcts.newFunction(fct);
    const newFocus = (!target || !fct) ? undefined : { target, fct };
    fcts.clean(newFocus);
    selectFocus(newFocus);
  }, [ selection ]);

  const [ probe, setProbe ] = React.useState<Maybe<Probe>>(undefined);
  React.useEffect(() => {
    if (focus) probes.request({ loc: focus, callstack: cs }).then(setProbe);
    else setProbe(undefined);
  }, [ focus ]);

  const removeLoc = (loc: Location): void => {
    fcts.removeLocation(loc);
    if (loc.target === focus?.target)
      selectFocus(undefined);
  };

  const setLocPin = (loc: Location, pin: boolean): void => {
    if (pin) fcts.pin(loc); else fcts.unpin(loc);
    forceUpdate();
  }

  const functionsProps: FunctionProps[] = fcts.map((infos, fct) => {
    const { byCallstacks, folded } = infos;
    const setFolded = (folded: boolean): void => {
      fcts.setFolded(fct, folded);
      forceUpdate();
    }
    const setByCS = (byCS: boolean): void => fcts.setByCallstacks(fct, byCS);
    const locStatus = (_loc: Location): MarkerStatus => 'JustFocused';
    return {
      fct,
      markers: infos.markers(focus),
      display,
      close: () => { fcts.delete(fct); forceUpdate(); },
      getProbe: probes.get,
      selectLoc: selectFocus,
      locStatus,
      removeLoc,
      addLoc: fcts.pin,
      folded,
      setFolded,
      byCallstacks,
      getCallstacks: callstacks.get,
      setByCallstacks: setByCS,
      selectCallstack: setCS,
      isSelectedCallstack,
      setSelection,
    };
  });

  return (
    <>
      <Ivette.TitleBar />
      <Vfill>
        <ProbeInfos
          probe={probe}
          status={fcts.status(focus)}
          setLocPin={setLocPin}
          removeLoc={removeLoc}
          display={display}
          setDisplay={setDisplay}
        />
        {functionsProps.map(FunctionSection)}
      </Vfill>
      <AlarmsInfos probe={probe} />
      <StackInfos
        callsites={callsites.get(cs) ?? []}
        setSelection={setSelection}
      />
    </>
  );
}
