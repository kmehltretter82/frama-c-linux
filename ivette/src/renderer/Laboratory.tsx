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
import * as States from 'dome/data/states';
import * as Sidebars from 'dome/frame/sidebars';
import { Icon } from 'dome/controls/icons';
import { Label } from 'dome/controls/labels';
import { Hbox, Hfill, Vfill } from 'dome/layout/boxes';
import { QPane, QSplit } from 'dome/layout/qsplit';
import { RenderElement } from 'dome/layout/dispatch';
import { Catch } from 'dome/errors';
import { classes } from 'dome/misc/utils';
import * as Ivette from 'ivette';
import * as Ext from './Extensions';

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
  dockedComponents: [],
  selectedView: "default"
};
const globalLabViewState = new States.GlobalState<LabViewState>(
  defaultLabViewState
);
const defaultPanelLayoutSelectorState: PanelLayoutSelectorState ={
  display: false,
  compId: "",
  compLabel: "",
  origin: "sidebar",
  y: 0
};
const globalPanelLayoutSelectorState = new States
.GlobalState<PanelLayoutSelectorState>(defaultPanelLayoutSelectorState);

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

function assignCompToQuarter(quarter: string, compId: string): void {
  const labViewState = globalLabViewState.getValue();
  const layout = assignValueToQuarterStr(quarter, compId);
  if (layout.A === "") layout.A = labViewState.A ?? "";
  if (layout.B === "") layout.B = labViewState.B ?? "";
  if (layout.C === "") layout.C = labViewState.C ?? "";
  if (layout.D === "") layout.D = labViewState.D ?? "";

  // TODO : replace with Tabs
  applyLayout({
    id: "custom",
    label: "Custom Layout",
    layout: layout
   });
}

function applyLayout(view : Ivette.ViewLayoutProps): void {
  const { layout } = view;
  let A, B, C, D;

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

  const state = globalLabViewState.getValue();
  const components = state.components;
  Object.values(layout).forEach(compId => {
    components.add(compId);
  });

  globalLabViewState.setValue({
    ...state,
    A: A, B: B, C: C, D: D,
    components: components,
    selectedView: view.id,
  });
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
  dockedComponents: Ivette.ComponentProps[]
  selectedView: string;
}

export function LabView(): JSX.Element {

  const [state, setState] = States.useGlobalState(globalLabViewState);

  const setH = React.useCallback(
    (newH: number) => {
      setState({ ...state, H: newH });
    }, [state, setState]
  );

  const setV = React.useCallback(
    (newV: number) => {
      setState({ ...state, V: newV });
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
    return (
      <Sidebars.Section label="Views" defaultUnfold>
        {views.map((view) =>
          <Sidebars.Item
            key={view.id}
            label={view.label}
            title={view.title}
            icon='DISPLAY'
            selected={selectedView === view.id}
            onSelection={() => applyLayout(view)}
          />
        )}
      </Sidebars.Section>
    );
}

/* -------------------------------------------------------------------------- */
/* --- Component Sidebar Item                                             --- */
/* -------------------------------------------------------------------------- */

function ComponentItem(comp: Ivette.ItemProps): JSX.Element {
  function onSelection(): void {
    const compObject = COMPONENT.getElement(comp.id);
    const preferredPosition = compObject?.preferredPosition ?? "D";
    assignCompToQuarter(preferredPosition, comp.id);
  }

  function onContextMenu(e: React.MouseEvent): void {
    const state = globalPanelLayoutSelectorState.getValue();
    const display = !state.display ? true : state.compId !== comp.id;
    globalPanelLayoutSelectorState.setValue({
      display: display,
      compId: display ? comp.id : "",
      compLabel: display ? comp.label : "",
      origin: "sidebar",
      y: e.clientY
    });
  }

  return (
    <div onContextMenu={e => onContextMenu(e)}>
      <Sidebars.Item
        icon='COMPONENT'
        label={comp.label}
        title={comp.title}
        onSelection={onSelection} />
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
  origin: "sidebar" | "titlebar" | "dockbar";
  y: number;
}

export function PanelLayoutSelector()
: JSX.Element {
  const [state, ] =
  States.useGlobalState(globalPanelLayoutSelectorState);
  const className = classes(
    state.display ? '' : 'dome-erased',
    "panelLayoutSelector"
  );
  const iconSize = 30;

  function computePanelY(): number {
    const panelHeight = 350;
    const maxHeight = window.innerHeight;
    let y = 0;

    y = state.y - panelHeight/2 > 0 ? state.y - panelHeight/2 : 0;
    if (y > maxHeight - panelHeight) y = maxHeight - panelHeight;
    return y;
  }

  const y = computePanelY();

  function onclick(quarter: string): void {
    assignCompToQuarter(quarter, state.compId);
  }

  function close(): void {
    globalPanelLayoutSelectorState.setValue({
      display: false,
      compId: "",
      compLabel: "",
      origin: "sidebar",
      y: 0
    });
  }

  function dock(): void {
    const component: Ivette.ComponentProps = {
      id: state.compId,
      label: state.compLabel
    };
    const labviewState = globalLabViewState.getValue();
    labviewState.dockedComponents =
    [...labviewState.dockedComponents, component];
    globalLabViewState.setValue(labviewState);
  }

  function remove(): void {
    const labviewState = globalLabViewState.getValue();
    labviewState.dockedComponents =
    labviewState.dockedComponents.filter((comp) => comp.id === state.compId);
    globalLabViewState.setValue(labviewState);
  }

  return (
    <div className={className} style={{ top: y }}>
      <Label>{state.compLabel}</Label>
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
        <div className="panelLayoutSelector-spaced">
          Dock Panel
          <Icon id={"QSPLIT.DOCK"} size={iconSize}
          className="panelLayoutSelector-hover"
          onClick={dock} />
        </div>
        { state.origin !== "sidebar" &&
          <div className="panelLayoutSelector-spaced">
            Remove Panel
            <Icon id="TRASH" size={iconSize}
            className="panelLayoutSelector-hover"
            onClick={remove} />
          </div>
        }
        <div className="panelLayoutSelector-spaced">
          Close Window
          <Icon id={"CROSS"} size={iconSize}
          className="panelLayoutSelector-hover"
          onClick={() => close()} />
        </div>
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
  const [ state ] = React.useState(
    globalLabViewState.getValue()
  );

  // TODO : left/right click

  return (
    <>
    {
    state.dockedComponents.map((comp) =>
      <span key={comp.id}>{comp.label}</span>
    )}
    </>
  );
}

/* -------------------------------------------------------------------------- */
