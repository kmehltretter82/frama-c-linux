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
import * as Ivette from 'ivette';
import * as Ctrl from "dome/controls/buttons";
import * as Disp from "dome/controls/displays";
import * as Sidebars from 'dome/frame/sidebars';
import * as Box from "dome/layout/boxes";
import * as Qsplit from "dome/layout/qsplit";
import * as States from '../dome/renderer/data/states';
import * as Ext from './Extensions';

const COMPONENT = Ivette.COMPONENT;
const VIEW = Ivette.VIEW;

/* -------------------------------------------------------------------------- */
/* --- Mocking                                                            --- */
/* -------------------------------------------------------------------------- */

const mockCompoIdA = "fc.kernel.messages";
const mockLayout: Ivette.Layout1 = { ABCD: mockCompoIdA };

/* -------------------------------------------------------------------------- */
/* --- Quarter                                                            --- */
/* -------------------------------------------------------------------------- */

function Quarter(props: {
  value?: string;
  possibleValues: string[];
  setValue: (v: string | undefined) => void;
}): JSX.Element {
  const onChange = (s?: string): void => props.setValue(s ? s : undefined);
  return (
    <Ctrl.Select value={props.value ?? ""} onChange={onChange}>
      <option value="">-</option>
      {props.possibleValues.map((v, key) => {
        return <option key={key} value={v}>{v}</option>;
      })}
    </Ctrl.Select>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Pane                                                               --- */
/* -------------------------------------------------------------------------- */

function Pane(props: { id: string; background: string }): JSX.Element {
  const { id, background } = props;

  // eslint-disable-next-line no-console
  console.log("getElement of ", id, COMPONENT.getElement(id));

  const css: React.CSSProperties = {
    width: "100%",
    height: "100%",
    textAlign: "center",
    background,
  };

  const children = COMPONENT.getElement(id)?.children;

  return (
  <Qsplit.QPane id={id}>
    {children ?? <div style={css}>{id}</div>}
  </Qsplit.QPane>
  );
}

const round = (r: number): number => Math.round(r * 100) / 100;

/* -------------------------------------------------------------------------- */
/* --- LabView                                                            --- */
/* -------------------------------------------------------------------------- */

export function LabView(): JSX.Element {
  const globalLayoutState = new States.GlobalState<Ivette.Layout>(mockLayout);
  const layoutState = States.useGlobalState(globalLayoutState);
  const [layout, setLayout] = layoutState;

  Ivette.registerSidebar({
    id: 'fc.ivette.views',
    label: 'Views',
    rank: 1,
    children: <ViewBar setLayout={setLayout}/>
  });

  const [H, setH] = React.useState(0.5);
  const [V, setV] = React.useState(0.5);

  const [A, setA] = React.useState<string | undefined>("A");
  const [B, setB] = React.useState<string | undefined>("B");
  const [C, setC] = React.useState<string | undefined>("C");
  const [D, setD] = React.useState<string | undefined>("D");

  const applyDefaultLayout = React.useCallback(
    () => {
      // set the component to display in each quarter based on the
      // layout provided
      if("A" in layout) setA(layout.A);
      if("B" in layout) setB(layout.B);
      if("C" in layout) setC(layout.C);
      if("D" in layout) setD(layout.D);

      if("AB" in layout) { setA(layout.AB); setB(layout.AB); }
      if("AC" in layout) { setA(layout.AC); setC(layout.AC); }
      if("BD" in layout) { setB(layout.BD); setD(layout.BD); }
      if("CD" in layout) { setC(layout.CD); setD(layout.CD); }

      if("ABCD" in layout) {
        setA(layout.ABCD);
        setB(layout.ABCD);
        setC(layout.ABCD);
        setD(layout.ABCD);
      }
    }, [layout]
  );

  const setPosition = React.useCallback(
    (h, v) => {
      setH(h);
      setV(v);
    },
    [setH, setV]
  );
  const reset = (): void => {
    setPosition(0.5, 0.5);
    applyDefaultLayout();
  };
  const clear = (): void => {
    setPosition(0.5, 0.5);
    setA(undefined);
    setB(undefined);
    setC(undefined);
    setD(undefined);
  };

  // Available components for the selected view
  const viewComponents = Object.values(layout);

  // Load the layout components
  React.useEffect(() => {
    applyDefaultLayout();
  }, [applyDefaultLayout]);

  return (
    <Box.Vfill>
      <Box.Hfill>
        <Ctrl.Button icon="RELOAD" label="Reset" onClick={reset} />
        <Ctrl.Button icon="TRASH" label="Clear" onClick={clear} />
        <Box.Space />
        <Disp.LCD>
          H={round(H)} V={round(V)}
        </Disp.LCD>
        <Box.Space />
        <Quarter value={A} setValue={setA} possibleValues={viewComponents}/>
        <Quarter value={B} setValue={setB} possibleValues={viewComponents} />
        <Quarter value={C} setValue={setC} possibleValues={viewComponents} />
        <Quarter value={D} setValue={setD} possibleValues={viewComponents} />
      </Box.Hfill>
      <Qsplit.QSplit A={A} B={B} C={C} D={D} H={H} V={V}
      setPosition={setPosition}>
        <Pane id={A ?? "A"} background="lightblue" />
        <Pane id={B ?? "B"} background="lightgreen" />
        <Pane id={C ?? "C"} background="#8282db" />
        <Pane id={D ?? "D"} background="coral" />
      </Qsplit.QSplit>
    </Box.Vfill>
  );
}

/* -------------------------------------------------------------------------- */
/* --- ViewBar                                                            --- */
/* -------------------------------------------------------------------------- */

export interface ViewBarProps {
  setLayout(layout: Ivette.Layout): void;
}

export function ViewBar(props: ViewBarProps): JSX.Element {

  const views= Ext.useElements(VIEW);

  // eslint-disable-next-line no-console
  console.log("Ext.useElements(VIEW): ", views);

  const itemsView = views?.map((view, key) => (
    <Sidebars.Item
    key={key}
    label="Item label"
    title="Item title"
    onSelection={() => props.setLayout(view.layout)}
    >
      <span>{view.label}</span>
    </Sidebars.Item>
  ));

  return (
    <Sidebars.SideBar>
      <Sidebars.Section label="Views">
        <div>{ itemsView }</div>
      </Sidebars.Section>
    </Sidebars.SideBar>
  );
}

/* -------------------------------------------------------------------------- */
