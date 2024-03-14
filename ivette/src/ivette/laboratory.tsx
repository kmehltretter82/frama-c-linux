/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2023                                                */
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
import * as Dome from 'dome';
import * as Json from 'dome/data/json';
import * as States from 'dome/data/states';
import * as Settings from 'dome/data/settings';
import * as Sidebars from 'dome/frame/sidebars';
import * as Toolbar from 'dome/frame/toolbars';
import { Icon } from 'dome/controls/icons';
import { IconButton } from 'dome/controls/buttons';
import { Label } from 'dome/controls/labels';
import { Hbox, Hfill, Vfill, Grid } from 'dome/layout/boxes';
import { QPane, QSplit } from 'dome/layout/qsplit';
import { RenderElement } from 'dome/layout/dispatch';
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import * as Ivette from 'ivette';
import { compId, LayoutPosition, VIEW, COMPONENT, GROUP } from 'ivette';
import * as State from 'ivette/state';

/* -------------------------------------------------------------------------- */
/* --- LabView State                                                      --- */
/* -------------------------------------------------------------------------- */

type tabKey = string;
type viewId = string;

interface Split { H: number, V: number }
interface Layout { A: compId, B: compId, C: compId, D: compId }

interface TabViewState {
  key: tabKey, /* viewId@custom for custom, or viewId */
  viewId: viewId,
  custom: number, /* -1: transient, 0: favorite, n: custom */
  split: Split,
  stack: Layout[], /* current at index 0 */
}

interface LabViewState {
  split: Split;
  stack: Layout[];
  panels: Set<compId>;
  docked: Map<compId, LayoutPosition>;
  tabs: Map<tabKey, TabViewState>;
  tabKey: tabKey;
  sideView: viewId; // from Sidebar or TAB selection
  sideComp: compId; // from Sidebar selection
}

const defaultSplit: Split = { H: 0.5, V: 0.5 };
const defaultLayout: Layout = { A: '', B: '', C: '', D: '' };

const LAB = new States.GlobalState<LabViewState>({
  split: defaultSplit,
  stack: [defaultLayout],
  panels: new Set(),
  docked: new Map(),
  tabs: new Map(),
  tabKey: '',
  sideView: '',
  sideComp: '',
});

/* -------------------------------------------------------------------------- */
/* --- Settings Management                                                --- */
/* -------------------------------------------------------------------------- */

interface TabSettings {
  view: viewId,
  split: Split,
}

interface DockSettings {
  comp: compId,
  position: Ivette.LayoutPosition,
}

interface LabSettings {
  tabIndex: number;
  tabs: TabSettings[];
  dock: DockSettings[];
}

const jSplit: Json.Decoder<Split> =
  Json.jObject({
    H: Json.jRange(0, 1, 0.5),
    V: Json.jRange(0, 1, 0.5),
  });

const jPosition: Json.Decoder<Ivette.LayoutPosition> =
  (js: Json.json) => {
    switch(js) {
      case 'A': case 'B': case 'C': case 'D':
      case 'AB': case 'AC': case 'BD': case 'CD':
      case 'ABCD':
        return js;
      default:
        return 'D';
    }
  };

const jTabSettings: Json.Decoder<TabSettings> =
  Json.jObject({
    view: Json.jString,
    split: jSplit,
  });

const jDockSettings: Json.Decoder<DockSettings> =
  Json.jObject({
    comp: Json.jString,
    position: jPosition,
  });

const jLabSettings: Json.Decoder<LabSettings> =
  Json.jObject({
    tabIndex: Json.jNumber,
    tabs: Json.jCatch(Json.jArray(jTabSettings), []),
    dock: Json.jCatch(Json.jArray(jDockSettings), []),
  });

const eLabSettings: Json.Encoder<LabSettings> =
  (s: LabSettings): Json.json => ((s as object) as Json.json);

function labSettings(state: LabViewState): LabSettings {
  const tabs: TabSettings[] = [];
  let tabIndex = -1;
  state.tabs.forEach((tab: TabViewState) => {
    if (tab.custom === 0) {
      if (tab.key === state.tabKey)
        tabIndex = tabs.length;
      tabs.push({
        view: tab.viewId,
        split: tab.split,
      });
    }
  });
  const dock: DockSettings[] = [];
  state.docked.forEach((position, compId) => dock.push({
    comp: compId,
    position,
  }));
  return { tabIndex, tabs, dock };
}

const defaultSettings: LabSettings = {
  tabIndex: 0, tabs: [], dock: [],
};

/* -------------------------------------------------------------------------- */
/* --- Layout Utilities                                                   --- */
/* -------------------------------------------------------------------------- */

function compareLayout(u: Layout, v: Layout): boolean {
  return (
    u.A === v.A &&
    u.B === v.B &&
    u.C === v.C &&
    u.D === v.D
  );
}

function isDefined(m: Layout): boolean
{
  return !!m.A || !!m.B || !!m.C || !!m.D;
}

function isComplete(m: Layout): boolean
{
  return !m.A && !m.B && !m.C && !m.D;
}

const removeLayout = (compId: compId) => (layout: Layout) : Layout =>
  {
    const { A, B, C, D } = layout;
    return {
      A: A !== compId ? A : '',
      B: B !== compId ? B : '',
      C: C !== compId ? C : '',
      D: D !== compId ? D : '',
    };
  };

function addLayout(
  layout: Layout, compId: compId, at: LayoutPosition
): Layout
{
  switch(at) {
    case 'A': return { ...layout, A: compId };
    case 'B': return { ...layout, B: compId };
    case 'C': return { ...layout, C: compId };
    case 'D': return { ...layout, D: compId };
    case 'AB': return { ...layout, A: compId, B: compId };
    case 'AC': return { ...layout, A: compId, C: compId };
    case 'BD': return { ...layout, B: compId, D: compId };
    case 'CD': return { ...layout, C: compId, D: compId };
    case 'ABCD': return { A: compId, B: compId, C: compId, D: compId };
    default: return layout;
  }
}

function makeViewLayout(view: Ivette.Layout): Layout
{
  type Unstructured = {
    A ?: compId, B ?: compId, C ?: compId, D ?: compId,
    AB ?: compId, AC ?: compId, BD ?: compId, CD ?: compId,
    ABCD ?: compId
  };
  const u = view as Unstructured;
  const A : compId = u.A ?? u.AB ?? u.AC ?? u.ABCD ?? '';
  const B : compId = u.B ?? u.AB ?? u.BD ?? u.ABCD ?? '';
  const C : compId = u.C ?? u.AC ?? u.CD ?? u.ABCD ?? '';
  const D : compId = u.D ?? u.CD ?? u.BD ?? u.ABCD ?? '';
  return { A, B, C, D };
}

function unstackLayout(
  layout: Layout,
  stack: Layout[],
): Layout[]
{
  let k = 1;
  while( !isComplete(layout) && k < stack.length ) {
    const layer = stack[k];
    layout = {
      A: layout.A || layer.A,
      B: layout.B || layer.B,
      C: layout.C || layer.C,
      D: layout.D || layer.D,
    };
    k++;
  }
  return [layout, ... stack];
}

function addLayoutComponent(
  stack: Layout[],
  compId: compId,
  at: LayoutPosition
): Layout[]
{
  stack = stack.map(removeLayout(compId)).filter(isDefined);
  const top = stack[0] ?? defaultLayout;
  const layout = addLayout(top, compId, at);
  return unstackLayout(layout, stack.slice(1));
}

function removeLayoutComponent(stack: Layout[], compId: compId): Layout[]
{
  stack = stack.map(removeLayout(compId)).filter(isDefined);
  const top = stack[0] ?? defaultLayout;
  return unstackLayout(top, stack.slice(1));
}

function completeLayout(m: Layout): Layout
{
  let { A, B, C, D } = m;
  if (A && B && C && D) return m;
  if (!A) {
    const BD = B && B === D;
    const CD = C && C === D;
    A = BD ? C : CD ? B : (B || C || D);
  }
  if (!B) {
    const AC = A && A === C;
    const CD = C && C === D;
    B = AC ? D : CD ? A : (A || D || C);
  }
  if (!C) {
    const AB = A && A === B;
    const BD = B && B === D;
    C = AB ? D : BD ? A : (A || D || B);
  }
  if (!D) {
    const AB = A && A === B;
    const AC = A && A === C;
    D = AB ? C : AC ? B : (B || C || A);
  }
  return { A, B, C, D };
}

function getLayoutPosition(
  layout: Layout, compId: compId
): LayoutPosition | undefined
{
  const { A, B, C, D } = layout;
  const a = A === compId;
  const b = B === compId;
  const c = C === compId;
  const d = D === compId;
  if (a && b && c && d) return 'ABCD';
  if (a && b) return 'AB';
  if (a && c) return 'AC';
  if (b && d) return 'BD';
  if (c && d) return 'CD';
  if (a) return 'A';
  if (b) return 'B';
  if (c) return 'C';
  if (d) return 'D';
  return undefined;
}

/* -------------------------------------------------------------------------- */
/* --- Tabs Utilities                                                     --- */
/* -------------------------------------------------------------------------- */

function previousTab(tabs: Map<tabKey, TabViewState>, key: tabKey):
  TabViewState | undefined
{
  let prev: tabKey | undefined = undefined;
  let last: tabKey | undefined = undefined;
  tabs.forEach(t => {
    if (t.key === key) prev = last; else last = t.key;
  });
  const next = prev || last;
  return next && tabs.get(next);
}

function newCustom(tabs: Map<tabKey, TabViewState>, viewId: viewId): number
{
  let custom = 0;
  tabs.forEach(tab => {
    if (tab.viewId === viewId)
      custom = Math.max(custom, tab.custom);
  });
  return custom+1;
}

function newTab(
  tabs: Map<tabKey, TabViewState>,
  view: Ivette.ViewLayoutProps,
  custom: number,
): TabViewState
{
  const { id: viewId } = view;
  const key = custom > 0 ? `${viewId}@${custom}` : viewId;
  const tab = {
    key, viewId, custom,
    split: defaultSplit,
    stack: [makeViewLayout(view.layout)],
  };
  tabs.set(key, tab);
  return tab;
}

function saveTab(
  tabs: Map<tabKey, TabViewState>,
  oldState: LabViewState,
): void {
  const oldKey = oldState.tabKey;
  const toSave = tabs.get(oldKey);
  if (toSave !== undefined) {
    const { stack, split } = oldState;
    tabs.set(oldKey, { ...toSave, stack, split });
  }
}

function addPanels(panels: Set<compId>, layout: Layout): Set<compId>
{
  const { A, B, C, D } = layout;
  if ( panels.has(A) && panels.has(B) && panels.has(C) && panels.has(D) )
    return panels;
  else
    return copySet(panels).add(A).add(B).add(C).add(D);
}

/* -------------------------------------------------------------------------- */
/* --- LabView Actions                                                    --- */
/* -------------------------------------------------------------------------- */

function copySet<A>(s: Set<A>): Set<A>
{
  const r = new Set<A>();
  s.forEach((a) => r.add(a));
  return r;
}

function copyMap<A, B>(m: Map<A, B>): Map<A, B> {
  const u = new Map<A, B>();
  m.forEach((v, k) => u.set(k, v));
  return u;
}

function setCurrentView(viewId: viewId = ''):void {
  const state = LAB.getValue();
  LAB.setValue({ ...state, sideView: viewId, sideComp: '' });
}

function setCurrentComp(compId: compId = ''):void {
  const state = LAB.getValue();
  LAB.setValue({ ...state, sideComp: compId, sideView: '' });
}

function setCurrentNone(): void {
  const state = LAB.getValue();
  LAB.setValue({ ...state, sideComp: '', sideView: '' });
}

function applyTab(key: tabKey): void {
  const state = LAB.getValue();
  const old = state.tabKey;
  if (old === key) return;
  const tab = state.tabs.get(key);
  if (!tab) return;
  const { stack, split } = tab;
  const tabs = copyMap(state.tabs);
  const layout = stack[0] ?? defaultLayout;
  saveTab(tabs, state);
  const panels = addPanels(state.panels, layout);
  LAB.setValue({
    ...state,
    panels,
    stack,
    split,
    tabs,
    tabKey: key,
  });
}

function closeTab(key: tabKey): void {
  const state = LAB.getValue();
  const tab = previousTab(state.tabs, key);
  const tabs = copyMap(state.tabs);
  tabs.delete(key);
  if (tab === undefined) {
    LAB.setValue({
      ...state,
      stack: [],
      split: defaultSplit,
      tabs, tabKey: ''
    });
  } else {
    const { key, stack, split } = tab;
    const layout = stack[0] ?? defaultLayout;
    const panels = addPanels(state.panels, layout);
    LAB.setValue({
      ...state,
      panels, stack, split, tabs, tabKey: key
    });
  }
}

function restoreDefault(key: tabKey): void {
  const state = LAB.getValue();
  const tab = state.tabs.get(key);
  if (!tab) return;
  const view = VIEW.getElement(tab.viewId);
  if (!view) return;
  const layout = makeViewLayout(view.layout);
  const tabs = copyMap(state.tabs).set(key, { ...tab, stack: [layout] });
  if (key === state.tabKey) {
    LAB.setValue({ ...state, tabs, stack: [layout] });
  } else {
    LAB.setValue({ ...state, tabs });
  }
}

export function applyView(view: Ivette.ViewLayoutProps): void {
  const state = LAB.getValue();
  const viewId = view.id;
  if (state.tabs.has(viewId))
    applyTab(viewId);
  else {
    const layout = makeViewLayout(view.layout);
    const panels = addPanels(state.panels, layout);
    const tabs = copyMap(state.tabs);
    const tab = newTab(tabs, view, -1);
    saveTab(tabs, state);
    LAB.setValue({
      ...state,
      panels,
      split: defaultSplit,
      stack: [layout],
      tabs, tabKey: tab.key
    });
  }
}

function duplicateView(view: Ivette.ViewLayoutProps): void {
  const state = LAB.getValue();
  const custom = newCustom(state.tabs, view.id);
  const tabs = copyMap(state.tabs);
  newTab(tabs, view, custom);
  LAB.setValue({ ...state, tabs });
}

function applyFavorite(
  view: Ivette.ViewLayoutProps,
  favorite: boolean
): void {
  const state = LAB.getValue();
  const tab = state.tabs.get(view.id);
  if (tab) {
    const custom = favorite ? 0 : -1;
    const tabs = copyMap(state.tabs).set(tab.key, { ...tab, custom });
    LAB.setValue({ ...state, tabs });
  } else if (favorite) {
    const tabs = copyMap(state.tabs);
    newTab(tabs, view, 0);
    LAB.setValue({ ...state, tabs });
  }
}

export function applyComponent(
  comp: Ivette.ComponentProps,
  at?: LayoutPosition
): void {
  const state = LAB.getValue();
  const { id, preferredPosition } = comp;
  const pos = at ?? preferredPosition ?? 'D';
  const stack = addLayoutComponent(state.stack, id, pos);
  const panels = copySet(state.panels).add(id);
  LAB.setValue({ ...state, panels, stack });
}

export function dockComponent(
  comp: Ivette.ComponentProps,
  at?: Ivette.LayoutPosition
): void
{
  const { id, preferredPosition } = comp;
  const state = LAB.getValue();
  const top = state.stack[0] ?? defaultLayout;
  const pos =
    at ?? getLayoutPosition(top, id) ?? preferredPosition ?? 'D';
  const stack = removeLayoutComponent(state.stack, id);
  const docked = copyMap(state.docked).set(id, pos);
  LAB.setValue({ ...state, docked, stack });
}

function undockComponent(compId: compId): void
{
  const state = LAB.getValue();
  if (state.docked.has(compId)) {
    const docked = copyMap(state.docked);
    docked.delete(compId);
    LAB.setValue({ ...state, docked });
  }
}

function closeComponent(compId: compId): void
{
  const state = LAB.getValue();
  const stack = removeLayoutComponent(state.stack, compId);
  const panels = copySet(state.panels);
  const docked = copyMap(state.docked);
  panels.delete(compId);
  docked.delete(compId);
  LAB.setValue({ ...state, panels, docked, stack });
}

/* -------------------------------------------------------------------------- */
/* --- Settings Update                                                    --- */
/* -------------------------------------------------------------------------- */

let synchronize = true;

LAB.on((state: LabViewState) => {
  if (synchronize) {
    try {
      synchronize = false;
      const data = labSettings(state);
      Settings.setWindowSettings('ivette.laboratory', eLabSettings(data));
    } finally {
      synchronize = true;
    }
  }
});

Settings.onWindowSettings(() => {
  if (synchronize) {
    try {
      synchronize = false;
      const settings = Settings.getWindowSettings(
        'ivette.laboratory', jLabSettings, defaultSettings
      );
      let gotoView: viewId | undefined = undefined;
      settings.tabs.forEach((tab, index) => {
        const view = VIEW.getElement(tab.view);
        if (view !== undefined) {
          applyFavorite(view, true);
          if (index === settings.tabIndex) gotoView = tab.view;
        }
      });
      settings.dock.forEach(dock => {
        const comp = COMPONENT.getElement(dock.comp);
        if (comp !== undefined)
          dockComponent(comp, dock.position);
      });
      if (gotoView !== undefined) {
        const state = LAB.getValue();
        if (!state.tabKey) {
          applyTab(gotoView);
          setCurrentNone();
        }
      }
    } finally {
      synchronize = true;
    }
  }
});

/* -------------------------------------------------------------------------- */
/* --- Exported API                                                       --- */
/* -------------------------------------------------------------------------- */

export function useState(): LabViewState
{
  const [state] = States.useGlobalState(LAB);
  return state;
}

export interface ViewStatus {
  favorite: boolean;
  displayed: boolean;
  layout: Layout;
}

export function getViewStatus(
  state: LabViewState,
  viewId: viewId
): ViewStatus
{
  const tab = state.tabs.get(viewId);
  const favorite = tab ? tab.custom === 0 : false;
  const displayed = tab ? tab.key === state.tabKey : false;
  const layout = displayed ? state.stack[0] : tab?.stack[0];
  return { favorite, displayed, layout: layout ?? defaultLayout };
}

export interface ComponentStatus {
  active: boolean;
  docked: boolean;
  position: Ivette.LayoutPosition | undefined;
}

export function getComponentStatus(
  state: LabViewState,
  compId: compId
): ComponentStatus
{
  const layout = state.stack[0] ?? defaultLayout;
  const position = getLayoutPosition(layout, compId);
  const active = state.panels.has(compId);
  const docked = state.docked.has(compId);
  return { position, active, docked };
}

/* -------------------------------------------------------------------------- */
/* --- Layout Menu State                                                  --- */
/* -------------------------------------------------------------------------- */

interface Actions {
  dock: boolean;
  undock: boolean;
  close: boolean;
}

interface LayoutMenuState extends Actions {
  compId: compId;
  x: number;
  y: number;
  fromDock: boolean;
}

const closedMenu: LayoutMenuState = {
  compId: '',
  dock: false,
  undock: false,
  close: false,
  fromDock: false,
  x: 0,
  y: 0,
};

const MENU = new States.GlobalState<LayoutMenuState>(closedMenu);

function openLayoutMenu(
  compId: compId,
  actions: Actions,
  evt: React.MouseEvent,
  fromDock = false
): void {
  MENU.setValue({
    ...actions, compId,
    x: evt.clientX, y: evt.clientY, fromDock
  });
}

function closeMenu(): void {
  MENU.setValue(closedMenu);
}

/* -------------------------------------------------------------------------- */
/* --- Layout Menu Component                                              --- */
/* -------------------------------------------------------------------------- */

interface QuarterProps {
  compId: compId;
  layout: Layout;
  pos: LayoutPosition;
}

function Quarter(props: QuarterProps): JSX.Element {
  const { layout, compId, pos } = props;
  const icon = 'QSPLIT.' + pos;
  const onClick = ():void => {
    closeMenu();
    const comp = COMPONENT.getElement(compId);
    if (comp) applyComponent(comp, pos);
  };
  const curp = getLayoutPosition(layout, compId);
  return (
    <IconButton
      className='labview-layout-quarter'
      icon={icon}
      disabled={curp === pos}
      onClick={onClick} />
  );
}

interface ActionProps {
  icon: string;
  label: string;
  display: boolean;
  onClick: () => void;
}

function Action(props: ActionProps): JSX.Element {
  const { icon, label, display, onClick } = props;
  return (
    <Label
      className='labview-layout-action'
      display={display}
      label={label}
      onClick={onClick}
    >
      <Icon className='labview-layout-action-icon' id={icon}/>
    </Label>
  );
}

function LayoutMenu(): JSX.Element | null {
  const href = React.useRef<HTMLDivElement>(null);
  const divElt = href.current;
  const [menu] = States.useGlobalState(MENU);
  const [state] = States.useGlobalState(LAB);
  const [panelWidth, setWidth] = React.useState(80);
  const [panelHeight, setHeight] = React.useState(80);
  const layout = state.stack[0] ?? defaultLayout;
  const { compId, dock, undock, close } = menu;
  const display = compId !== '';

  React.useEffect(() => {
    if (display && divElt) {
      divElt.focus({ preventScroll: true });
    }
  }, [display, divElt]);

  const width = Math.max(divElt?.offsetWidth ?? 0, panelWidth);
  const height = Math.max(divElt?.offsetHeight ?? 0, panelHeight);
  React.useEffect(() => setWidth(width), [width]);
  React.useEffect(() => setHeight(height), [height]);

  const className = classes(
    'dome-color-frame',
    'labview-layout-menu',
    !display && 'dome-erased'
  );

  const maxWidth = window.innerWidth;
  const maxHeight = window.innerHeight;

  const left = Math.max(0, Math.min(menu.x, maxWidth - width));
  const top = Math.max(0, Math.min(menu.y, maxHeight - height));

  const onDock = (): void => {
    closeMenu();
    const comp = COMPONENT.getElement(compId);
    if (comp) dockComponent(comp);
  };

  const onUndock = (): void => {
    closeMenu();
    undockComponent(compId);
  };

  const onClose = (): void => {
    closeMenu();
    closeComponent(compId);
  };

  return (
    <div
      ref={href}
      tabIndex={0}
      className={className}
      style={menu.fromDock ? { left, bottom: 0 } : { left, top }}
      onBlur={closeMenu}
      onKeyDown={closeMenu}
    >
      <Grid columns='24px 24px 24px'>
        <Quarter compId={compId} layout={layout} pos='A'    />
        <Quarter compId={compId} layout={layout} pos='AB'   />
        <Quarter compId={compId} layout={layout} pos='B'    />
        <Quarter compId={compId} layout={layout} pos='AC'   />
        <Quarter compId={compId} layout={layout} pos='ABCD' />
        <Quarter compId={compId} layout={layout} pos='BD'   />
        <Quarter compId={compId} layout={layout} pos='C'    />
        <Quarter compId={compId} layout={layout} pos='CD'   />
        <Quarter compId={compId} layout={layout} pos='D'    />
      </Grid>
      <Action
        display={dock} label='Dock' icon='QSPLIT.DOCK' onClick={onDock} />
      <Action
        display={undock} label='Undock' icon='QSPLIT.DOCK' onClick={onUndock} />
      <Action
        display={close} label='Close' icon='TRASH' onClick={onClose} />
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Pane Component                                                     --- */
/* -------------------------------------------------------------------------- */

interface PaneProps { compId: compId }

const paneActions: Actions = { dock: true, undock: false, close: true };

function Pane(props: PaneProps): JSX.Element | null {
  const { compId } = props;
  const component = State.useElement(COMPONENT, compId);
  const onLayout = React.useCallback(
    (evt) => openLayoutMenu(compId, paneActions, evt),
    [compId]
  );
  if (!component) return null;
  const { label, title, children } = component;
  return (
    <QPane id={compId}>
      <Vfill className="labview-content">
        <Hbox className="labview-titlebar" onContextMenu={onLayout}>
          <Hfill>
            <Catch label={compId}>
              <RenderElement id={`labview.title.${compId}`}>
                <Label
                  className="labview-handle"
                  label={label}
                  title={title} />
              </RenderElement>
            </Catch>
          </Hfill>
        </Hbox>
        <Ivette.TitleContext.Provider value={{ id: compId, label, title }}>
          <Catch label={compId}>{children}</Catch>
        </Ivette.TitleContext.Provider>
      </Vfill>
    </QPane>
  );
}

/* -------------------------------------------------------------------------- */
/* --- LabView                                                            --- */
/* -------------------------------------------------------------------------- */

export function LabView(): JSX.Element {
  const [state] = States.useGlobalState(LAB);
  const setPosition = React.useCallback(
    (H, V) => LAB.setValue({ ...state, split: { H, V } }),
    [state]
  );
  const layout = state.stack[0] ?? defaultLayout;
  const { A, B, C, D } = completeLayout(layout);
  const { H, V } = state.split;
  const panels : JSX.Element[] = [];
  state.panels.forEach((id) => panels.push(<Pane key={id} compId={id}/>));
  return (
    <>
      <LayoutMenu />
      <QSplit
        className='labview-container'
        A={A} B={B} C={C} D={D} H={H} V={V}
        setPosition={setPosition}
      >{panels}</QSplit>
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- View Sidebar Section                                               --- */
/* -------------------------------------------------------------------------- */

interface ViewItemProps {
  view: Ivette.ViewLayoutProps;
  favorite: boolean;
  selected: boolean;
  displayed: boolean;
  layout: Layout | undefined;
}

export function ViewItem(props: ViewItemProps): JSX.Element {
  const { view, favorite, displayed, selected, layout } = props;
  const { id, label: vname, title: vtitle } = view;

  const onSelection = (_evt:React.MouseEvent): void => {
    setCurrentView(id);
    applyView(view);
  };

  const icon = favorite ? 'FAVORITE' : 'DISPLAY';
  const modified =
    (layout !== undefined &&
     !compareLayout(layout, makeViewLayout(view.layout)));

  const label = modified ? vname + '*' : vname;
  const tname = vtitle || vname;
  const title = modified ? tname + ' (modified)' : tname;

  const onContextMenu = (): void => {
    setCurrentView(id);
    const onDisplay = (): void => applyView(view);
    const onFavorite = (): void => applyFavorite(view, !favorite);
    const onRestore = (): void => restoreDefault(view.id);
    const onDuplicate = (): void => duplicateView(view);
    const favAction = !favorite ? 'Add to Favorite' : 'Remove from Favorite';
    Dome.popupMenu([
      { label: 'Display View', enabled: !displayed, onClick: onDisplay },
      { label: favAction, onClick: onFavorite },
      { label: 'Duplicate View', onClick: onDuplicate },
      { label: 'Restore Default', enabled: modified, onClick: onRestore },
    ]);
  };

  return (
    <Sidebars.Item
      key={id}
      icon={icon}
      label={label}
      title={title}
      selected={selected}
      onSelection={onSelection}
      onContextMenu={onContextMenu}
    />
  );
}

function ViewSection(): JSX.Element {
  const views = State.useElements(VIEW);
  const [{ tabs, tabKey, sideView, stack }] = States.useGlobalState(LAB);
  const items = views.map((view) => {
    const { id } = view;
    const tab = tabs.get(id);
    const favorite = tab ? tab.custom === 0 : false;
    const displayed = tab ? tab.key === tabKey : false;
    const layout = displayed ? stack[0] : tab?.stack[0];
    return (
      <ViewItem
        key={id}
        view={view}
        favorite={favorite}
        layout={layout}
        displayed={displayed}
        selected={id === sideView} />
    );
  });

  return (
    <Sidebars.Section
      settings="ivette.sidebar.views" label="Views" defaultUnfold
    >
      {items}
    </Sidebars.Section>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Component Sidebar Item                                             --- */
/* -------------------------------------------------------------------------- */

interface ComponentItemProps {
  comp: Ivette.ComponentProps;
  position: LayoutPosition | undefined;
  selected: boolean;
  active: boolean;
  docked: boolean;
}

export function ComponentItem(props: ComponentItemProps): JSX.Element {
  const { comp, position, selected, active, docked } = props;
  const { id, label, title = label } = comp;
  const icon =
    position ? 'QSPLIT.' + position :
    docked ? 'QSPLIT.DOCK' :
    'COMPONENT';

  const mlabel = !position && active ? label + '*' : label;

  const status =
    position ? 'Visible' :
    docked ? 'Docked' :
    active ? 'Running' : 'Closed';

  const onSelection = (): void => {
    setCurrentComp(id);
  };

  const onDoubleClick = (): void => {
    setCurrentComp(id);
    applyComponent(comp);
  };

  const onContextMenu = (evt: React.MouseEvent): void => {
    setCurrentComp(id);
    openLayoutMenu(id, { dock: !docked, undock: docked, close: active }, evt);
  };

  return (
    <Sidebars.Item
      icon={icon}
      label={mlabel}
      title={`${title} (${status})`}
      onSelection={onSelection}
      onDoubleClick={onDoubleClick}
      onContextMenu={onContextMenu}
      selected={selected}
    />
  );
}

/* -------------------------------------------------------------------------- */
/* --- Group Sidebar Section                                              --- */
/* -------------------------------------------------------------------------- */

interface ID { id: string }

export const inGroup = (g: ID) => (e: ID) => e.id.startsWith(g.id+'.');
export const groupOf = (e: ID) => (g: ID) => e.id.startsWith(g.id+'.');
export const inNoGroup = (gs: ID[]) => (e: ID) => !gs.some(groupOf(e));

interface GroupSectionProps extends Ivette.ItemProps {
  filter: (comp: ID) => boolean;
}

function GroupSection(props: GroupSectionProps): JSX.Element | null {
  const { id, label, title, filter } = props;
  const settings = 'ivette.sidebar.group.' + id;
  const components = State.useElements(COMPONENT).filter(filter) ?? [];
  const [{ panels, docked, sideComp, stack }] = States.useGlobalState(LAB);
  const layout = stack[0] ?? defaultLayout;
  const items = components.map((comp) => {
    const { id } = comp;
    return (
      <ComponentItem
        key={id}
        comp={comp}
        position={getLayoutPosition(layout, id)}
        selected={id === sideComp}
        active={panels.has(id)}
        docked={docked.has(id)}
      />
    );
  });
  return (
    <Sidebars.Section settings={settings} label={label} title={title}>
      {items}
    </Sidebars.Section>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Views & Components Sidebar                                         --- */
/* -------------------------------------------------------------------------- */

const Components: Ivette.ItemProps = {
  id: 'components',
  label: 'Other Plugins',
  title: 'Components from other Frama-C Plugins'
};

const Sandbox: Ivette.ItemProps = {
  id: 'sandbox',
  label: 'Sandbox',
  title: 'Sandbox Components (dev mode only)'
};

function ViewBar(): JSX.Element {
  const groups = State.useElements(GROUP);
  const allGroups = groups.concat(Sandbox);

  return (
    <Sidebars.SideBar>
      <ViewSection key='views'/>
      {groups.map((group) =>
        <GroupSection
          key={group.id}
          filter={inGroup(group)} {...group} />)}
      <GroupSection
        key='components'
        filter={inNoGroup(allGroups)} {...Components} />
      <GroupSection
        key='sandbox'
        filter={inGroup(Sandbox)} {...Sandbox} />
    </Sidebars.SideBar>
  );
}

Ivette.registerSidebar({
  id: "ivette.views",
  label: "Views",
  title: "View Selector",
  children: <ViewBar />,
});

// --------------------------------------------------------------------------
// --- Docked Components
// --------------------------------------------------------------------------

interface DockItemProps {
  compId: compId;
  visible: boolean;
  position: LayoutPosition;
}

function DockItem(props: DockItemProps): JSX.Element | null {
  const { compId, visible, position } = props;
  const comp = State.useElement(COMPONENT, compId);
  if (comp === undefined) return null;
  const label = comp.label ?? compId;
  const icon = 'QSPLIT.' + position;
  const title = `Display ${label} (right-click for more actions)`;

  const className = classes(
    'labview-docked', visible && 'disabled',
  );

  const onClick = (): void => {
    if (visible) {
      dockComponent(comp);
    } else {
      applyComponent(comp, position);
    }
    setCurrentNone();
  };

  const onContextMenu = (evt: React.MouseEvent): void => {
    openLayoutMenu(compId, {
      dock: visible,
      undock: true,
      close: true
    }, evt, true);
  };

  return (
    <Label
      className={className}
      icon={icon}
      label={label}
      title={title}
      onClick={onClick}
      onContextMenu={onContextMenu}
    />
  );
}

export function Dock(): JSX.Element {
  const [{ docked, stack }] = States.useGlobalState(LAB);
  const items: JSX.Element[] = [];
  docked.forEach((pos, compId) => {
    const layout = stack[0] ?? defaultLayout;
    const curr = getLayoutPosition(layout, compId);
    items.push(
      <DockItem
        key={compId}
        compId={compId}
        visible={curr !== undefined}
        position={curr ?? pos}
      />);
  });
  return <>{items}</>;
}

/* -------------------------------------------------------------------------- */
/* --- Tabs                                                               --- */
/* -------------------------------------------------------------------------- */

interface TabViewProps {
  tab: TabViewState;
  tabKey: tabKey;
  layout: Layout;
}

function TabView(props: TabViewProps): JSX.Element | null {
  const { tab, tabKey } = props;
  const { viewId, custom, key } = tab;
  const view = State.useElement(VIEW, viewId);
  if (!view) return null;
  const selected = key === tabKey;
  const top = tab.stack[0] ?? defaultLayout;
  const layout = selected ? props.layout : top;
  const modified = !compareLayout(layout, makeViewLayout(view.layout));
  const vname = view.label;
  const favorite = custom === 0;
  const tname = custom > 0 ? `${vname} ~ ${custom}` : vname;
  const label = modified ? `${tname}*` : tname;
  const tdup = custom > 0 ? 'Custom ' : '';
  const tmod = modified ? ' (modified)': '';
  const title = tdup + vname + tmod;

  const onClick = (): void => { applyTab(key); setCurrentNone(); };
  const onClose = (): void => closeTab(key);
  const onContextMenu = (): void => {
    const onDisplay = (): void => applyTab(key);
    const onFavorite = (): void => applyFavorite(view, !favorite);
    const onRestore = (): void => restoreDefault(key);
    const favAction = !favorite ? 'Add to Favorite' : 'Remove from Favorite';
    Dome.popupMenu([
      { label: 'Display View', enabled: !selected, onClick: onDisplay },
      { label: favAction, display: custom <= 0, onClick: onFavorite },
      { label: 'Restore Default', enabled: modified, onClick: onRestore },
      { label: 'Close Tab', display: custom < 0, onClick: onClose },
    ]);
  };

  return (
    <Toolbar.Button
      className='labview-tab'
      icon={selected ? 'DISPLAY' : undefined}
      label={label}
      title={title}
      selected={selected}
      onClick={onClick}
      onContextMenu={onContextMenu}
    >
      <IconButton
        className='labview-tab-closing'
        icon={custom === 0 ? 'FAVORITE' : 'CIRC.CLOSE'}
        enabled={custom !== 0}
        onClick={onClose}
      />
    </Toolbar.Button>
  );
}

export function Tabs(): JSX.Element {
  const [{ tabKey, stack, tabs }] = States.useGlobalState(LAB);
  const layout = stack[0] ?? defaultLayout;
  const items: JSX.Element[] = [];
  tabs.forEach((tab: TabViewState) =>
    items.push(
      <TabView
        key={tab.key}
        tab={tab}
        tabKey={tabKey}
        layout={layout}
      />
  ));
  return <>{items}</>;
}

/* -------------------------------------------------------------------------- */
