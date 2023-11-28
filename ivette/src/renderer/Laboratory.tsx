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
import { DEVEL } from 'dome';
import * as States from 'dome/data/states';
import * as Sidebars from 'dome/frame/sidebars';
import { Label } from 'dome/controls/labels';
import { Hbox, Hfill, Vfill } from 'dome/layout/boxes';
import { QPane, QSplit } from 'dome/layout/qsplit';
import { RenderElement } from 'dome/layout/dispatch';
import { Catch } from 'dome/errors';
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
  selectedView: "default"
};
const globalLabViewState = new States.GlobalState<LabViewState>(
  defaultLabViewState
);

function applyLayout(viewId : string, newLayout: Ivette.Layout):void {
  let A, B, C, D;

  if("A" in newLayout) A = newLayout.A;
  if("B" in newLayout) B = newLayout.B;
  if("C" in newLayout) C = newLayout.C;
  if("D" in newLayout) D = newLayout.D;

  if("AB" in newLayout) {
    A = newLayout.AB;
    B = newLayout.AB;
  }
  if("AC" in newLayout) {
    A = newLayout.AC;
    C = newLayout.AC;
  }
  if("BD" in newLayout) {
    B = newLayout.BD;
    D = newLayout.BD;
  }
  if("CD" in newLayout) {
    C = newLayout.CD;
    D = newLayout.CD;
  }

  if("ABCD" in newLayout) {
    A = newLayout.ABCD;
    B = newLayout.ABCD;
    C = newLayout.ABCD;
    D = newLayout.ABCD;
  }

  const state = globalLabViewState.getValue();
  const components = state.components;
  Object.values(newLayout).forEach(compId => {
    components.add(compId);
  });

  globalLabViewState.setValue({
    ...state,
    A: A, B: B, C: C, D: D,
    components: components,
    selectedView: viewId
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
    <QSplit
      className='labview-container'
      A={state.A} B={state.B} C={state.C} D={state.D} H={state.H} V={state.V}
      setPosition={setPosition}
    >
      {[...state.components].map((comp, key) =>
        <Pane key={key} id={comp} />
      )}
    </QSplit>
  );
}

/* -------------------------------------------------------------------------- */
/* --- ViewBar                                                            --- */
/* -------------------------------------------------------------------------- */

export function ViewBar(): JSX.Element {
  const [selected, setSelected] = React.useState("");
  const views = Ext.useElements(VIEW);
  const groups = Ext.useElements(GROUP);
  const components = Ext.useElements(COMPONENT);
  const compsByGroup: Map<string, Ivette.ComponentProps[]> = new Map();
  const defaultGroupName = "ungrouped";
  const sandboxGroupName = "sandbox";
  const sandboxGroupId = "sandbox";

  groups.forEach(group => {
    compsByGroup.set(group.id, []);
    components.forEach(comp => {
      comp.id.startsWith(group.id) && compsByGroup.get(group.id)?.push(comp);
    });
  });

  compsByGroup.set(defaultGroupName, []);
  let groupedComponents: Ivette.ComponentProps[] = [];
  compsByGroup.forEach(val =>
    groupedComponents = groupedComponents.concat(val));
  components.forEach(comp => {
    if(groupedComponents.indexOf(comp) === -1) {
      compsByGroup.get(defaultGroupName)?.push(comp);
    }
  });

  const compsSandbox = compsByGroup.get(sandboxGroupId);
  compsByGroup.delete(sandboxGroupId);

  return (
    <Sidebars.SideBar>
      <Sidebars.Section label="Views" defaultUnfold>
        {views.map((view) =>
          <Sidebars.Item
            key={view.id}
            label={view.label}
            title={view.title}
            icon='DISPLAY'
            selected={globalLabViewState.getValue().selectedView === view.id}
            onSelection={() => {
              applyLayout(view.id, view.layout);
              setSelected(view.id);
            }}
          />
        )}
      </Sidebars.Section>
      {
        Array.from(compsByGroup.keys()).map((group, key) => {
          const items: JSX.Element[] = [];

          compsByGroup.get(group)?.forEach(comp => {
            items.push(
              <Sidebars.Item
                key={comp.id}
                label={comp.label}
                title={comp.title}
                icon='COMPONENT'
                selected={selected === comp.id}
                onSelection={() => {
                  setSelected(comp.id);
                }}
              />
            );
          });

          return (
            <Sidebars.Section key= {key} label={group}>
              {items}
            </Sidebars.Section>
          );
        })
      }
      { DEVEL &&
        <Sidebars.Section label={sandboxGroupName}>
          {compsSandbox && compsSandbox.map((compo) =>
            <Sidebars.Item
              key={compo.id}
              label={compo.label}
              title={compo.title}
              icon='COMPONENT'
              selected={selected === compo.id}
              onSelection={() => {
                setSelected(compo.id);
              }}
            />
          )}
        </Sidebars.Section>
      }
    </Sidebars.SideBar>
  );
}

Ivette.registerSidebar({
  id: "ivette.views",
  rank: 100,
  label: "Views",
  title: "View Selector",
  children: <ViewBar />,
});

/* -------------------------------------------------------------------------- */
