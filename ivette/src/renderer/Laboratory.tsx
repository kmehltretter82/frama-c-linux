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

import React from "react";
import * as Dome from 'dome';
import * as States from 'dome/data/states';
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
import * as Ext from './Extensions';

/* -------------------------------------------------------------------------- */
/* --- LabView State                                                      --- */
/* -------------------------------------------------------------------------- */

type viewId = string;

interface Scroll { H: number, V: number }
interface Layout { A: compId, B: compId, C: compId, D: compId }

interface TabViewState {
  view: viewId,
  custom: number,
  scroll: Scroll,
  layout: Layout,
}

interface LabViewState {
  scroll: Scroll;
  layout: Layout;
  panels: Set<compId>;
  docked: Map<compId, LayoutPosition>;
  tabs: TabViewState[];
  tabIndex: number;
  sideView: viewId; // from Sidebar or TAB selection
  sideComp: compId; // from Sidebar selection
}

const defaultScroll: Scroll = { H: 0.5, V: 0.5 };
const defaultLayout: Layout = { A: '', B: '', C: '', D: '' };

const LAB = new States.GlobalState<LabViewState>({
  scroll: defaultScroll,
  layout: defaultLayout,
  panels: new Set(),
  docked: new Map(),
  tabs: [],
  tabIndex: 0,
  sideView: '',
  sideComp: '',
});

/* -------------------------------------------------------------------------- */
/* --- Layout Utilities                                                   --- */
/* -------------------------------------------------------------------------- */

function removeComponent(m: Layout, cid: compId): Layout
{
  const { A, B, C, D } = m;
  return {
    A: A !== cid ? A : '',
    B: B !== cid ? B : '',
    C: A !== cid ? C : '',
    D: A !== cid ? D : '',
  };
}

function addComponent(m: Layout, cid: compId, p: LayoutPosition): Layout
{
  m = removeComponent(m, cid);
  switch(p) {
    case 'A': return { ...m, A: cid };
    case 'B': return { ...m, B: cid };
    case 'C': return { ...m, C: cid };
    case 'D': return { ...m, D: cid };
    case 'AB': return { ...m, A: cid, B: cid };
    case 'AC': return { ...m, A: cid, C: cid };
    case 'BD': return { ...m, B: cid, D: cid };
    case 'CD': return { ...m, C: cid, D: cid };
    case 'ABCD': return { A: cid, B: cid, C: cid, D: cid };
    default: return m;
  }
}

function addLayout(m: Layout, view: Ivette.Layout): Layout
{
  type Unstructured = {
    A ?: compId, B ?: compId, C ?: compId, D ?: compId,
    AB ?: compId, AC ?: compId, BD ?: compId, CD ?: compId,
    ABCD ?: compId
  };
  const u = view as Unstructured;
  const A : compId = u.A ?? u.AB ?? u.AC ?? u.ABCD ?? m.A;
  const B : compId = u.B ?? u.AB ?? u.BD ?? u.ABCD ?? m.B;
  const C : compId = u.C ?? u.AC ?? u.CD ?? u.ABCD ?? m.C;
  const D : compId = u.D ?? u.CD ?? u.BD ?? u.ABCD ?? m.D;
  return { A, B, C, D };
}

function getPosition(m: Layout, cid: compId): LayoutPosition | undefined
{
  const { A, B, C, D } = m;
  const a = A === cid;
  const b = B === cid;
  const c = C === cid;
  const d = D === cid;
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

{
  getPosition(addComponent(defaultLayout, 'Console', 'A'), 'Console');
}

/* -------------------------------------------------------------------------- */
/* --- LabView Actions                                                    --- */
/* -------------------------------------------------------------------------- */

function setCurrentView(view: viewId = ''):void {
  const state = LAB.getValue();
  LAB.setValue({ ...state, sideView: view, sideComp: '' });
}

function setCurrentComp(comp: compId = ''):void {
  const state = LAB.getValue();
  LAB.setValue({ ...state, sideComp: comp, sideView: '' });
}

function applyView(view: Ivette.ViewLayoutProps): void {
  const state = LAB.getValue();
  const layout = addLayout(state.layout, view.layout);
  const panels = state.panels;
  // Side effect on state.panels, but it is OK
  panels.add(layout.A);
  panels.add(layout.B);
  panels.add(layout.C);
  panels.add(layout.D);
  LAB.setValue({ ...state, panels, layout, sideView: view.id, sideComp: '' });
}

/* -------------------------------------------------------------------------- */
/* --- Layout Menu State                                                  --- */
/* -------------------------------------------------------------------------- */

interface Actions {
  dock: boolean;
  close: boolean;
}

interface LayoutMenuState extends Actions {
  comp: compId;
  x: number;
  y: number;
}

const closedMenu: LayoutMenuState = {
  comp: '',
  dock: false,
  close: false,
  x: 0,
  y: 0,
};

const MENU = new States.GlobalState<LayoutMenuState>(closedMenu);

function openLayoutMenu(
  comp: compId,
  actions: Actions,
  evt: React.MouseEvent
): void {
  MENU.setValue({ ...actions, comp, x: evt.clientX, y: evt.clientY });
}

function closeMenu(): void {
  MENU.setValue(closedMenu);
}

/* -------------------------------------------------------------------------- */
/* --- Layout Menu Component                                              --- */
/* -------------------------------------------------------------------------- */

interface QuarterProps {
  comp: compId;
  pos: LayoutPosition;
}

function Quarter(props: QuarterProps): JSX.Element {
  const { pos } = props;
  const icon = 'QSPLIT.' + pos;
  const onClick = ():void => {
    closeMenu();
  };
  return (
    <IconButton
      className='labview-layout-quarter'
      icon={icon}
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
  const { comp, dock, close } = menu;
  const display = comp !== '';

  React.useEffect(() => {
    if (display && divElt) {
      divElt.focus({ preventScroll: true });
    }
  }, [display, divElt]);

  const className = classes(
    'dome-color-frame',
    'labview-layout-menu',
    !display && 'dome-erased'
  );

  const maxWidth = window.innerWidth;
  const maxHeight = window.innerHeight;
  const panelWidth = divElt?.offsetWidth ?? 0;
  const panelHeight = divElt?.offsetHeight ?? 0;

  const left = Math.max(0, Math.min(menu.x, maxWidth - panelWidth));
  const top = Math.max(0, Math.min(menu.y, maxHeight - panelHeight));

  const onDock = (): void => { closeMenu(); };
  const onClose = (): void => { closeMenu(); };

  return (
    <div
      ref={href}
      tabIndex={0}
      className={className}
      style={{ left, top }}
      onBlur={closeMenu}
      onKeyDown={closeMenu}
    >
      <Grid columns='24px 24px 24px'>
        <Quarter comp={comp} pos='A'    />
        <Quarter comp={comp} pos='AB'   />
        <Quarter comp={comp} pos='B'    />
        <Quarter comp={comp} pos='AC'   />
        <Quarter comp={comp} pos='ABCD' />
        <Quarter comp={comp} pos='BD'   />
        <Quarter comp={comp} pos='C'    />
        <Quarter comp={comp} pos='CD'   />
        <Quarter comp={comp} pos='D'    />
      </Grid>
      <Action display={dock}
              label='Dock' icon='QSPLIT.DOCK' onClick={onDock} />
      <Action display={close}
              label='Close' icon='TRASH' onClick={onClose} />
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Pane Component                                                     --- */
/* -------------------------------------------------------------------------- */

interface PaneProps { comp: compId }

const paneActions: Actions = { dock: true, close: true };

function Pane(props: PaneProps): JSX.Element | null {
  const { comp } = props;
  const component = Ext.useElement(COMPONENT, comp);
  const onLayout = React.useCallback(
    (evt) => openLayoutMenu(comp, paneActions, evt),
    [comp]
  );
  if (!component) return null;
  const { label, title, children } = component;
  return (
    <QPane id={comp}>
      <Vfill className="labview-content">
        <Hbox className="labview-titlebar" onContextMenu={onLayout}>
          <Hfill>
            <Catch label={comp}>
              <RenderElement id={`labview.title.${comp}`}>
                <Label
                  className="labview-handle"
                  label={label}
                  title={title} />
              </RenderElement>
            </Catch>
          </Hfill>
        </Hbox>
        <Ivette.TitleContext.Provider value={{ id: comp, label, title }}>
          <Catch label={comp}>{children}</Catch>
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
    (H, V) => LAB.setValue({ ...state, scroll: { H, V } }),
    [state]
  );
  const { H, V } = state.scroll;
  const { A, B, C, D } = state.layout;
  const panels : JSX.Element[] = [];
  state.panels.forEach((id) => panels.push(<Pane key={id} comp={id}/>));
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
  selected: boolean;
}

function ViewItem(props: ViewItemProps): JSX.Element {
  const { view, selected } = props;
  const { id, label, title } = view;

  const onSelection = (_evt:React.MouseEvent): void => {
    applyView(view);
  };

  const onContextMenu = (): void => {
    setCurrentView(id);
    Dome.popupMenu([
      { label: 'Display View' },
      { label: 'Duplicate View' },
      { label: 'Restore Default' },
    ]);
  };

  return (
    <Sidebars.Item
      key={id}
      label={label}
      title={title}
      icon='DISPLAY'
      selected={selected}
      onSelection={onSelection}
      onContextMenu={onContextMenu}
    />
  );
}

function ViewSection(): JSX.Element {
  const views = Ext.useElements(VIEW);
  const [{ sideView }] = States.useGlobalState(LAB);

  const items = views.map((view) => {
    const { id } = view;
    return (
      <ViewItem key={id} view={view} selected={id === sideView} />
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
  selected: boolean;
  active: boolean;
  docked: boolean;
}

function ComponentItem(props: ComponentItemProps): JSX.Element {
  const { comp, selected, active, docked } = props;
  const { id, label, title } = comp;

  const onSelection = (): void => {
    setCurrentComp(id);
  };

  const onContextMenu = (evt: React.MouseEvent): void => {
    setCurrentComp(id);
    openLayoutMenu(id, { dock: !docked, close: active }, evt);
  };

  return (
    <Sidebars.Item
      icon='COMPONENT'
      label={label}
      title={title}
      onSelection={onSelection}
      onContextMenu={onContextMenu}
      selected={selected}
    />
  );
}

/* -------------------------------------------------------------------------- */
/* --- Group Sidebar Section                                              --- */
/* -------------------------------------------------------------------------- */

interface ID { id: string }

const inGroup = (group: ID) => (elt: ID) => elt.id.startsWith(group.id+'.');
const groupOf = (elt: ID) => (group: ID) => elt.id.startsWith(group.id+'.');
const inNoGroup = (groups: ID[]) => (elt: ID) => !groups.some(groupOf(elt));

interface GroupSectionProps extends Ivette.ItemProps {
  filter: (comp: ID) => boolean;
}

function GroupSection(props: GroupSectionProps): JSX.Element | null {
  const { id, label, title, filter } = props;
  const settings = 'ivette.sidebar.group.' + id;
  const components = Ext.useElements(COMPONENT).filter(filter) ?? [];
  const [{ panels, docked, sideComp }] = States.useGlobalState(LAB);
  const items = components.map((comp) => {
    const { id } = comp;
    return (
      <ComponentItem
        key={id}
        comp={comp}
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
  const groups = Ext.useElements(GROUP);
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

const dockActions: Actions = { dock: false, close: true };

interface DockItemProps {
  comp: compId;
  pos: LayoutPosition;
}

function DockItem(props: DockItemProps): JSX.Element {
  const { comp: id, pos } = props;
  const comp = Ext.useElement(COMPONENT, id);
  const label = comp?.label ?? id;
  const icon = 'QSPLIT.' + pos;
  const title = `Display ${label} (right-click for more actions)`;
  const onContextMenu = (_: void, evt: React.MouseEvent): void => {
    openLayoutMenu(id, dockActions, evt);
  };
  return (
    <Toolbar.Button
      icon={icon}
      label={label}
      title={title}
      onContextMenu={onContextMenu}
    />
  );
}

export function Dock(): JSX.Element {
  const [{ docked }] = States.useGlobalState(LAB);
  const items: JSX.Element[] = [];
  docked.forEach((pos, comp) => {
    items.push(<DockItem key={comp} comp={comp} pos={pos} />);
  });
  return <>{items}</>;
}

/* -------------------------------------------------------------------------- */
/* --- Tabs                                                               --- */
/* -------------------------------------------------------------------------- */

interface TabViewProps {
  tab: TabViewState;
  index: number;
  selected: number;
}

function TabView(props: TabViewProps): JSX.Element | null {
  const { tab, index, selected } = props;
  const { view: id, custom } = tab;
  const view = Ext.useElement(VIEW, id);
  const name = view?.label ?? id;
  const label = custom > 0 ? `${name} — ${custom}` : name;
  return (
    <Toolbar.Button
      icon='DISPLAY'
      label={label}
      value={index}
      selection={selected}
    />
  );
}

export function Tabs(): JSX.Element {
  const [{ tabs, tabIndex }] = States.useGlobalState(LAB);
  const items = tabs.map((tab, k) => (
    <TabView
      key={tab.view}
      tab={tab}
      index={k}
      selected={tabIndex} />
  ));
  return <>{items}</>;
}

/* -------------------------------------------------------------------------- */
