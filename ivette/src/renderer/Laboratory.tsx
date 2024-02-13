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
import { Label } from 'dome/controls/labels';
import { Hbox, Hfill, Vfill } from 'dome/layout/boxes';
import { QPane, QSplit } from 'dome/layout/qsplit';
import { RenderElement } from 'dome/layout/dispatch';
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import * as Ivette from 'ivette';
import * as Ext from './Extensions';


type PanelOrigin = "sidebar" | "titlebar" | "dockbar" | "";
const VIEW = Ivette.VIEW;
const COMPONENT = Ivette.COMPONENT;
const GROUP = Ivette.GROUP;
const defaultLayout = { ABCD: "" };
const defaultLabViewState: LabViewState = {
  A: defaultLayout.ABCD,
  B: defaultLayout.ABCD,
  C: defaultLayout.ABCD,
  D: defaultLayout.ABCD,
  H: 0.5,
  V: 0.5,
  components: new Set<string>(),
  dockedComponents: new Set<Ivette.ComponentProps>(),
  selectedView: "default",
  selectedTabIndex: 0
};
const globalLabViewState = new States.GlobalState<LabViewState>(
  defaultLabViewState
);
const defaultPanelLayoutSelectorState: PanelLayoutSelectorState ={
  display: false,
  compId: "",
  compLabel: "",
  origin: "",
  x: 0,
  y: 0
};
const globalPanelLayoutSelectorState = new States
.GlobalState<PanelLayoutSelectorState>(defaultPanelLayoutSelectorState);
const defaultTabsState: TabState = {
  tabs: [
    {
      viewId: "tab.default",
      viewLabel: "Default Tab",
      A: defaultLayout.ABCD,
      B: defaultLayout.ABCD,
      C: defaultLayout.ABCD,
      D: defaultLayout.ABCD,
      H: defaultLabViewState.H,
      V: defaultLabViewState.V
    }
  ]
};
const globalTabsState = new States.GlobalState<TabState>(defaultTabsState);

function assignValueToQuarterStr(quarter: string, value: string)
: Ivette.Layout4 {
  let A = "",
      B = "",
      C = "",
      D = "";

  if("A" === quarter) A = value;
  if("B" === quarter) B = value;
  if("C" === quarter) C = value;
  if("D" === quarter) D = value;

  if("AB" === quarter) {
    A = value;
    B = value;
  }
  if("AC" === quarter) {
    A = value;
    C = value;
  }
  if("BD" === quarter) {
    B = value;
    D = value;
  }
  if("CD" === quarter) {
    C = value;
    D = value;
  }

  if("ABCD" === quarter) {
    A = value;
    B = value;
    C = value;
    D = value;
  }

  return {
    A: A,
    B: B,
    C: C,
    D: D,
  };
}

function getQuarterComponents(quarter: string): (string | undefined)[] {
  const result = [];
  const labViewState = globalLabViewState.getValue();

  if ("A" === quarter) result.push(labViewState.A);
  if ("B" === quarter) result.push(labViewState.B);
  if ("C" === quarter) result.push(labViewState.C);
  if ("D" === quarter) result.push(labViewState.D);

  if ("AB" === quarter) {
    result.push(labViewState.A);
    result.push(labViewState.B);
  }
  if ("AC" === quarter) {
    result.push(labViewState.A);
    result.push(labViewState.C);
  }
  if ("BD" === quarter) {
    result.push(labViewState.B);
    result.push(labViewState.D);
  }
  if ("CD" === quarter) {
    result.push(labViewState.C);
    result.push(labViewState.D);
  }

  if ("ABCD" === quarter) {
    result.push(labViewState.A);
    result.push(labViewState.B);
    result.push(labViewState.C);
    result.push(labViewState.D);
  }

  return result;
}

function addToDockedComponents(comp: Ivette.ComponentProps)
: void {
  const labviewState = globalLabViewState.getValue();

  let exists = false;
  [...labviewState.dockedComponents].forEach(c => {
    if (c.id === comp.id) exists = true;
  });
  if(exists) return;

  const dockedComponents = labviewState.dockedComponents;
  dockedComponents.add(comp);
  globalLabViewState.setValue({
    ...labviewState,
    dockedComponents: dockedComponents
  }, true);
}

function deleteFromDockedComponents(comp: Ivette.ComponentProps): void {
  const labviewState = globalLabViewState.getValue();
  const dockedComponents = labviewState.dockedComponents;

  let exists = false;
  const tmpArray = Array.from(dockedComponents);
  tmpArray.forEach(c => {
    if (c.id === comp.id) {
      exists = true;
      tmpArray.splice(tmpArray.indexOf(c), 1);
    }
  });
  if(!exists) return;

  globalLabViewState.setValue({
    ...labviewState,
    dockedComponents: new Set(tmpArray)
  }, true);
}

function deleteFromLoadedComponents(comp: Ivette.ComponentProps): void {
  const labviewState = globalLabViewState.getValue();
  const loadedComponents = labviewState.components;

  let exists = false;
  const tmpArray = Array.from(loadedComponents);
  tmpArray.forEach(c => {
    if (c === comp.id) {
      exists = true;
      tmpArray.splice(tmpArray.indexOf(c), 1);
    }
  });
  if(!exists) return;

  globalLabViewState.setValue({
    ...labviewState,
    components: new Set(tmpArray),
  }, true);
}

function removeComponent(comp: Ivette.ComponentProps): void {
  removeCompFromCurrentLayout(comp.id);
  deleteFromDockedComponents(comp);
  deleteFromLoadedComponents(comp);
}

function addCompFromQuarterToDock(quarter: string): void {
  const replacedCompIds = getQuarterComponents(quarter);
  replacedCompIds.forEach(compId => {
    if(compId !== undefined) {
      const replacedComp = COMPONENT.getElement(compId);
      if(replacedComp !== undefined) {
       addToDockedComponents(replacedComp);
      }
    }
  });
}

function adjustBlanksInLayout(
  layout: { A: string, B: string, C: string, D: string }):
  {A: string, B: string, C: string, D: string} {
  Object.values(layout).forEach(compId => {
    let occurences = 0;
    Object.values(layout).forEach(c => {
      if (compId === c) occurences++;
    });

    if(occurences === 3) {
      if (layout.D === compId && occurences > 1) {
        layout.D = "";
        occurences--;
      }
      if (layout.C === compId && occurences > 1) {
        layout.C = "";
        occurences--;
      }
      if (layout.B === compId && occurences > 1) {
        layout.B = "";
        occurences--;
      }
      if (layout.A === compId && occurences > 1) {
        layout.C = "";
        occurences--;
      }
    }
  });
  return layout;
}

function removeCompFromCurrentLayout(compId: string): void {
  const labViewState = globalLabViewState.getValue();
  if (labViewState.A === compId) labViewState.A = "";
  if (labViewState.B === compId) labViewState.B = "";
  if (labViewState.C === compId) labViewState.C = "";
  if (labViewState.D === compId) labViewState.D = "";
  globalLabViewState.setValue(labViewState);
}

function assignCompToQuarter(quarter: string, compId: string): void {
  const labViewState = globalLabViewState.getValue();
  removeCompFromCurrentLayout(compId);
  addCompFromQuarterToDock(quarter);

  let layout = assignValueToQuarterStr(quarter, compId);
  if (layout.A === "") layout.A = labViewState.A ?? "";
  if (layout.B === "") layout.B = labViewState.B ?? "";
  if (layout.C === "") layout.C = labViewState.C ?? "";
  if (layout.D === "") layout.D = labViewState.D ?? "";
  layout = adjustBlanksInLayout(
    { A: layout.A, B: layout.B, C: layout.C, D: layout.D });

  const view = VIEW.getElement(labViewState.selectedView);
  applyLayout({
    id: view?.id ?? "view.custom",
    label: view?.label ?? "Custom Layout",
    layout: layout
   });
}

function getQuarterCompsFromLayout(layout: Ivette.Layout):
{A: string, B: string, C: string, D: string} {
  let A = "", B = "", C = "", D = "";
  if("A" in layout) A = layout.A;
  if("B" in layout) B = layout.B;
  if("C" in layout) C = layout.C;
  if("D" in layout) D = layout.D;

  if("AB" in layout) {
    A = layout.AB;
    B = layout.AB;
  }
  if("AC" in layout) {
    A = layout.AC;
    C = layout.AC;
  }
  if("BD" in layout) {
    B = layout.BD;
    D = layout.BD;
  }
  if("CD" in layout) {
    C = layout.CD;
    D = layout.CD;
  }

  if("ABCD" in layout) {
    A = layout.ABCD;
    B = layout.ABCD;
    C = layout.ABCD;
    D = layout.ABCD;
  }
  return { A: A, B: B, C: C, D: D };
}

function applyLayout(view : Ivette.ViewLayoutProps): void {
  const { layout } = view;
  const tabsState = globalTabsState.getValue();
  const parsedLayout = getQuarterCompsFromLayout(layout);
  addCompFromQuarterToDock("ABCD");

  let state = globalLabViewState.getValue();
  const components = state.components;
  Object.values(layout).forEach(compId => {
    compId !== "" && components.add(compId);
    const component = COMPONENT.getElement(compId);
    if(component && component !== undefined) {
      deleteFromDockedComponents(component);
    }
  });
  state = globalLabViewState.getValue();

  globalLabViewState.setValue({
    ...state,
    A: parsedLayout.A, B: parsedLayout.B, C: parsedLayout.C, D: parsedLayout.D,
    H: tabsState.tabs[state.selectedTabIndex].H,
    V: tabsState.tabs[state.selectedTabIndex].V,
    components: components,
    selectedView: view.id,
  });

  tabsState.tabs[state.selectedTabIndex] = {
    viewId: view.id,
    viewLabel: view.label,
    A: parsedLayout.A, B: parsedLayout.B, C: parsedLayout.C, D: parsedLayout.D,
    H: tabsState.tabs[state.selectedTabIndex].H,
    V: tabsState.tabs[state.selectedTabIndex].V
  };
  globalTabsState.setValue({ ...tabsState }, true);
}


/* -------------------------------------------------------------------------- */
/* --- Pane Component                                                     --- */
/* -------------------------------------------------------------------------- */

interface PaneProps { id: string; }

function Pane(props: PaneProps): JSX.Element | null {
  const { id } = props;
  const component = Ext.useElement(COMPONENT, id);
  if (!component) return null;
  const { label, title, children } = component;
  return (
    <QPane id={id}>
      <Vfill className="labview-content">
        <Hbox className="labview-titlebar">
          <Hfill>
            <Catch label={id}>
              <RenderElement id={`labview.title.${id}`}>
                <Label
                  className="labview-handle"
                  label={label}
                  title={title} />
              </RenderElement>
            </Catch>
            <Icon id={"ITEMS.GRID"}
              className="titlebar-thin-icon"
              onClick={(e) =>
                openPanelLayoutSelector(component, "titlebar", e)}
            />
          </Hfill>
        </Hbox>
        <Ivette.TitleContext.Provider value={{ id, label, title }}>
          <Catch label={id}>{children}</Catch>
        </Ivette.TitleContext.Provider>
      </Vfill>
    </QPane>
  );
}

/* -------------------------------------------------------------------------- */
/* --- LabView                                                            --- */
/* -------------------------------------------------------------------------- */

interface LabViewState {
  A: string | undefined;
  B: string | undefined;
  C: string | undefined;
  D: string | undefined;
  H: number;
  V: number;
  components: Set<string>
  dockedComponents: Set<Ivette.ComponentProps>
  selectedView: string,
  selectedTabIndex: number;
}

export function LabView(): JSX.Element {

  const [state, setState] = States.useGlobalState(globalLabViewState);

  const setH = React.useCallback(
    (newH: number) => {
      setState({ ...state, H: newH });
      const tabsState = globalTabsState.getValue();
      tabsState.tabs[state.selectedTabIndex].H = newH;
      globalTabsState.setValue({ ...tabsState });
    }, [state, setState]
  );

  const setV = React.useCallback(
    (newV: number) => {
      setState({ ...state, V: newV });
      const tabsState = globalTabsState.getValue();
      tabsState.tabs[state.selectedTabIndex].V = newV;
      globalTabsState.setValue({ ...tabsState });
    }, [state, setState]
  );

  const setPosition = React.useCallback(
    (h, v) => {
      setH(h);
      setV(v);
    },
    [setH, setV]
  );

  return (
    <>
      <PanelLayoutSelector />
      <QSplit
        className='labview-container'
        A={state.A} B={state.B} C={state.C} D={state.D} H={state.H} V={state.V}
        setPosition={setPosition}
      >
        {[...state.components].map((comp, key) =>
          <Pane key={key} id={comp} />
        )}
      </QSplit>
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- View Sidebar Section                                               --- */
/* -------------------------------------------------------------------------- */

function ViewSection(): JSX.Element {
  const views = Ext.useElements(VIEW);
  const [{ selectedView }] = States.useGlobalState(globalLabViewState);

  function createTabFromView(view: Ivette.ViewLayoutProps): void {
    const layout = getQuarterCompsFromLayout(view.layout);
    const tab: Tab = {
      viewId: view.id,
      viewLabel: view.label,
      A: layout.A,
      B: layout.B,
      C: layout.C,
      D: layout.D,
      H: defaultLabViewState.H,
      V: defaultLabViewState.V,
    };
    addTab(tab);
  }

  function applyView(view: Ivette.ViewLayoutProps): void {
    applyLayout(view);
    const labViewState = globalLabViewState.getValue();
    const tabsState = globalTabsState.getValue();
    globalLabViewState.setValue({
      ...labViewState,
      H: defaultLabViewState.H,
      V: defaultLabViewState.V
    });
    tabsState.tabs[labViewState.selectedTabIndex] = {
      ...tabsState.tabs[labViewState.selectedTabIndex],
      H: defaultLabViewState.H,
      V: defaultLabViewState.V
    };
  }

  function onSelection(view: Ivette.ViewLayoutProps, e?:React.MouseEvent):
  void {
    e?.shiftKey ? createTabFromView(view) : applyView(view);
  }

  function onContextMenu(view: Ivette.ViewLayoutProps): void {
    const items: Dome.PopupMenuItem[] = [
      {
        label: 'Apply view to current Tab',
        onClick: () => applyView(view),
      },
      {
        label: 'Create new Tab from view',
        onClick: () => createTabFromView(view),
      }
    ];
    Dome.popupMenu(items);
  }

  return (
    <Sidebars.Section label="Views" defaultUnfold>
      {views.map((view) =>
        <Sidebars.Item
          key={view.id}
          label={view.label}
          title={view.title}
          icon='DISPLAY'
          selected={selectedView === view.id}
          onSelection={(evt) => onSelection(view, evt)}
          onContextMenu={() => onContextMenu(view)}
        />
      )}
    </Sidebars.Section>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Component Sidebar Item                                             --- */
/* -------------------------------------------------------------------------- */

function ComponentItem(comp: Ivette.ItemProps): JSX.Element {
  const [ labViewState, ] = States.useGlobalState(globalLabViewState);
  const [ panelLayoutSelectorState, ] =
   States.useGlobalState(globalPanelLayoutSelectorState);
  const selected = panelLayoutSelectorState.compId === comp.id;
  const disabled = labViewState.components.has(comp.id);

  function onSelection(): void {
    const compObject = COMPONENT.getElement(comp.id);
    const preferredPosition = compObject?.preferredPosition ?? "D";
    assignCompToQuarter(preferredPosition, comp.id);
  }

  function onContextMenu(e: React.MouseEvent): void {
    if(labViewState.components.has(comp.id)
    || labViewState.dockedComponents.has(comp)) {
      globalPanelLayoutSelectorState.setValue(defaultPanelLayoutSelectorState);
      return;
    }
    openPanelLayoutSelector(comp, "sidebar", e);
  }

  return (
    <div onContextMenu={e => onContextMenu(e)}>
      <Sidebars.Item
        icon='COMPONENT'
        label={comp.label}
        title={comp.title}
        onSelection={onSelection}
        selected={selected}
        disabled={disabled} />
    </div>
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
  const components = Ext.useElements(COMPONENT).filter(filter);
  if (!components.length) return null;
  return (
    <Sidebars.Section settings={settings} label={label} title={title}>
      {components.map((comp) => <ComponentItem key={comp.id} {...comp} />)}
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

/* -------------------------------------------------------------------------- */
/* --- PanelLayoutSelector                                                --- */
/* -------------------------------------------------------------------------- */

interface PanelLayoutSelectorState {
  display: boolean;
  compId: string;
  compLabel: string;
  origin: PanelOrigin;
  x: number,
  y: number;
}

function openPanelLayoutSelector(comp: Ivette.ComponentProps,
  origin: PanelOrigin, e?: React.MouseEvent): void {
  const state = globalPanelLayoutSelectorState.getValue();
  const display = !state.display ? true : state.compId !== comp.id;
  globalPanelLayoutSelectorState.setValue({
    display: display,
    compId: display ? comp.id : "",
    compLabel: display ? comp.label : "",
    origin: origin,
    x: e?.clientX ?? 250,
    y: e?.clientY ?? 250
  });
}

function closePanelLayoutSelector(): void {
  globalPanelLayoutSelectorState.setValue(defaultPanelLayoutSelectorState);
}

function PanelLayoutSelector()
: JSX.Element {
  const [state, ] =
  States.useGlobalState(globalPanelLayoutSelectorState);
  const className = classes(
    state.display ? '' : 'dome-erased',
    "panelLayoutSelector"
  );
  const iconSize = 30;
  let x = 0, y = 0;
  computePanelXY();

  Dome.escaped.on(() => {
    closePanelLayoutSelector();
  });

  function computePanelXY(): void {
    const panelWidth = 200;
    const panelHeight = 250;
    const maxWidth = window.innerWidth;
    const maxHeight = window.innerHeight;

    x = state.x + 50;
    if (x + panelWidth > maxWidth) x = maxWidth - panelWidth;

    y = state.y - panelHeight/2 > 0 ? state.y - panelHeight/2 : 0;
    if (y + panelHeight > maxHeight) y = maxHeight - panelHeight;
  }

  function onclick(quarter: string): void {
    assignCompToQuarter(quarter, state.compId);
    closePanelLayoutSelector();
  }

  function dock(): void {
    const component: Ivette.ComponentProps = {
      id: state.compId,
      label: state.compLabel
    };
    addToDockedComponents(component);
    removeCompFromCurrentLayout(component.id);
    closePanelLayoutSelector();
  }

  function remove(): void {
    const component: Ivette.ComponentProps = {
      id: state.compId,
      label: state.compLabel
    };
    removeComponent(component);
    closePanelLayoutSelector();
  }

  return (
    <div className={className} style={{ left: x, top: y }}>
      <table>
        <tbody>
          <tr>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.A"} size={iconSize}
              onClick={() => onclick("A")} /></th>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.AB"} size={iconSize}
              onClick={() => onclick("AB")} /></th>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.B"} size={iconSize}
              onClick={() => onclick("B")} /></th>
          </tr>
          <tr>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.AC"} size={iconSize}
              onClick={() => onclick("AC")} /></th>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.ABCD"} size={iconSize}
              onClick={() => onclick("ABCD")} /></th>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.BD"} size={iconSize}
              onClick={() => onclick("BD")} /></th>
          </tr>
          <tr>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.C"} size={iconSize}
              onClick={() => onclick("C")} /></th>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.CD"} size={iconSize}
              onClick={() => onclick("CD")} /></th>
            <th className="panelLayoutSelector-hover">
              <Icon id={"QSPLIT.D"} size={iconSize}
              onClick={() => onclick("D")} /></th>
          </tr>
        </tbody>
      </table>
      <div>
        { state.origin !== "dockbar" &&
          <div className="panelLayoutSelector-spaced">
            Dock Panel
            <Icon id={"QSPLIT.DOCK"} size={iconSize}
            className="panelLayoutSelector-hover"
            onClick={dock} />
          </div>
        }
        { state.origin !== "sidebar" &&
          <div className="panelLayoutSelector-spaced">
            Remove Panel
            <Icon id="TRASH" size={iconSize}
            className="panelLayoutSelector-hover"
            onClick={remove} />
          </div>
        }
      </div>
    </div>
  );
}

Ivette.registerSandbox({
  id: 'sandbox.panelLayoutSelector',
  label: 'Panel Layout Selector',
  children: <PanelLayoutSelector />,
});


// --------------------------------------------------------------------------
// --- Docked Components
// --------------------------------------------------------------------------

export function Dock(): JSX.Element {

  const [ state, ] = States.useGlobalState(globalLabViewState);
  const [ panelLayoutSelectorState, ] =
  States.useGlobalState(globalPanelLayoutSelectorState);

  function onClick(comp: Ivette.ComponentProps): void {
    const compObject = COMPONENT.getElement(comp.id);
    const preferredPosition = compObject?.preferredPosition ?? "D";
    assignCompToQuarter(preferredPosition, comp.id);
    closePanelLayoutSelector();
  }

  function onContextMenu(comp: Ivette.ComponentProps, e?: React.MouseEvent):
  void {
    openPanelLayoutSelector(comp, "dockbar", e);
  }

  return (
    <>
      {
        [...state.dockedComponents].map((comp) =>
          <Toolbar.Button key={comp.id}
          label={comp.label}
          onClick={() => onClick(comp)}
          onContextMenu={(e) => onContextMenu(comp, e)}
          selected={panelLayoutSelectorState.compId === comp.id}
          />
        )
      }
    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Tabs                                                               --- */
/* -------------------------------------------------------------------------- */

interface Tab {
  viewLabel: string,
  viewId: string,
  A: string;
  B: string;
  C: string;
  D: string;
  H: number;
  V: number;
}

interface TabState {
  tabs: Tab[];
}

function addTab(tab: Tab): void {
  const tabsState = globalTabsState.getValue();
  tabsState.tabs.push(tab);
  globalTabsState.setValue({ ...tabsState }, true);
}

function removeTab(tab: Tab): void {
  const tabsState = globalTabsState.getValue();
  const labViewState = globalLabViewState.getValue();
  const activeTab = tabsState.tabs[labViewState.selectedTabIndex];

  tabsState.tabs.splice(tabsState.tabs.indexOf(tab), 1);
  labViewState.selectedTabIndex = tabsState.tabs.indexOf(activeTab);
  globalTabsState.setValue({ ...tabsState }, true);
  globalLabViewState.setValue({ ...labViewState });
}

export function Tabs(): JSX.Element {
  const [ state, setState ] = States.useGlobalState(globalTabsState);

  function switchTab(tab: Tab): void {
    const labViewState = globalLabViewState.getValue();
    labViewState.selectedTabIndex = state.tabs.indexOf(tab);
    globalLabViewState.setValue({ ...labViewState });
    applyLayout({
      id: tab.viewId,
      label: tab.viewLabel,
      layout: { A: tab.A, B: tab.B, C: tab.C, D: tab.D }
    });
  }

  function closeTab(tab: Tab): void {
    if(globalLabViewState.getValue().selectedTabIndex !==
    state.tabs.indexOf(tab)) {
      removeTab(tab);
    }
  }

  function resetTab(tab: Tab): void {
    const view = VIEW.getElement(tab.viewId);
    if (!view) return;
    const tabIndex = state.tabs.indexOf(tab);

    if(tabIndex === globalLabViewState.getValue().selectedTabIndex) {
      applyLayout(view);
      return;
    }
    const layout = getQuarterCompsFromLayout(view.layout);
    state.tabs[tabIndex].A = layout.A;
    state.tabs[tabIndex].B = layout.B;
    state.tabs[tabIndex].C = layout.C;
    state.tabs[tabIndex].D = layout.D;
    state.tabs[tabIndex].H = defaultLabViewState.H;
    state.tabs[tabIndex].V = defaultLabViewState.V;
    setState({ ...state });
  }

  function duplicateTab(tab: Tab): void {
    addTab({ ...tab });
  }

  function onClick(tab: Tab, e?:React.MouseEvent): void {
    e?.shiftKey ? duplicateTab(tab) : switchTab(tab);
  }

  function onContextMenu(tab: Tab): void {
    const labViewState = globalLabViewState.getValue();
    const items: Dome.PopupMenuItem[] = [
      {
        label: 'Switch active Tab',
        onClick: () => switchTab(tab),
        enabled: state.tabs.indexOf(tab) !== labViewState.selectedTabIndex
      },
      {
        label: 'Reset Tab to default view',
        onClick: () => resetTab(tab),
      },
      {
        label: 'Duplicate Tab',
        onClick: () => duplicateTab(tab),
      },
      {
        label: 'Close Tab',
        onClick: () => closeTab(tab),
        enabled: state.tabs.indexOf(tab) !== labViewState.selectedTabIndex
      }
    ];
    Dome.popupMenu(items);
  }

  return (
    <>
      {
        state.tabs.map(tab =>
          <Toolbar.Button key={state.tabs.indexOf(tab)}
          label={tab.viewLabel}
          onClick={(_a, e) => onClick(tab, e)}
          onContextMenu={() => onContextMenu(tab)}
          selected={globalLabViewState.getValue().selectedTabIndex ===
            state.tabs.indexOf(tab)}
          />
        )
      }
    </>
  );
}


/* -------------------------------------------------------------------------- */
