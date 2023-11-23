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
import * as Sidebars from 'dome/frame/sidebars';
import * as Box from "dome/layout/boxes";
import * as Qsplit from "dome/layout/qsplit";
import * as States from 'dome/data/states';
import { Catch } from 'dome/errors';
import * as Ivette from 'ivette';
import * as Ext from './Extensions';

const VIEW = Ivette.VIEW;
const COMPONENT = Ivette.COMPONENT;

/* -------------------------------------------------------------------------- */
/* --- Pane                                                               --- */
/* -------------------------------------------------------------------------- */

interface PaneProps { id: string; }

function Pane(props: PaneProps): JSX.Element {
  const { id } = props;
  const component = Ext.useElement(COMPONENT, id);
  return (
    <Qsplit.QPane id={id}>
      <Catch label={id}>
        {component?.children ?? null}
      </Catch>
    </Qsplit.QPane>
  );
}

/* -------------------------------------------------------------------------- */
/* --- LabView                                                            --- */
/* -------------------------------------------------------------------------- */

const defaultLayout = { ABCD: "" };
const globalLayoutState = new States.GlobalState<Ivette.Layout>(defaultLayout);

export function LabView(): JSX.Element {
  const [layout] = States.useGlobalState(globalLayoutState);

  const [H, setH] = React.useState(0.5);
  const [V, setV] = React.useState(0.5);
  const [A, setA] = React.useState<string | undefined>("A");
  const [B, setB] = React.useState<string | undefined>("B");
  const [C, setC] = React.useState<string | undefined>("C");
  const [D, setD] = React.useState<string | undefined>("D");

  const applyDefaultLayout = React.useCallback(
    () => {
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

  // Load the layout components
  React.useEffect(() => {
    applyDefaultLayout();
  }, [applyDefaultLayout]);

  return (
    <Box.Vfill>
      <Qsplit.QSplit
        A={A} B={B} C={C} D={D} H={H} V={V}
        setPosition={setPosition}>
        <Pane id={A ?? "A"} />
        <Pane id={B ?? "B"} />
        <Pane id={C ?? "C"} />
        <Pane id={D ?? "D"} />
      </Qsplit.QSplit>
    </Box.Vfill>
  );
}

/* -------------------------------------------------------------------------- */
/* --- ViewBar                                                            --- */
/* -------------------------------------------------------------------------- */

export function ViewBar(): JSX.Element {
  const views = Ext.useElements(VIEW);
  return (
    <Sidebars.SideBar>
      <Sidebars.Section label="Views" defaultUnfold>
        {views.map((view) =>
          <Sidebars.Item
            key={view.id}
            label={view.label}
            title={view.title}
            onSelection={() => globalLayoutState.setValue(view.layout)}
          />
        )}
      </Sidebars.Section>
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
