/* ************************************************************************ */
/*                                                                          */
/*   This file is part of Frama-C.                                          */
/*                                                                          */
/*   Copyright (C) 2007-2024                                                */
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
import { IconButton } from 'dome/controls/buttons';
import * as Ivette from 'ivette';
import * as Ast from 'frama-c/kernel/api/ast';
import * as States from 'frama-c/states';
import * as Eva from 'frama-c/plugins/eva/api/values';
import { FlameGraph } from 'react-flame-graph';
import AutoSizer, { Size } from 'react-virtualized-auto-sizer';
import { EvaReady, EvaStatus } from './components/AnalysisStatus';
import { Inset } from 'dome/frame/toolbars';
import { useFlipSettings } from 'dome';

// --- Flamegraph Table ---
interface Flamegraph {
  kfKey?: string;
  name: string;
  value: number;
  children?: Flamegraph[];
}

const addNodeToFlamegraph = (
  flamegraph: Flamegraph,
  cs: string[],
  row: Eva.evaFlamegraphData,
): void => {
  // Accumulate times for all nodes crossed
  flamegraph.value += row.time;
  // updating last node
  if(cs.length === 0) {
    flamegraph.kfKey = row.kfkey;
    return;
  }
  // Search/create next node
  if (!flamegraph.children) flamegraph.children = [];
  let nextNode = flamegraph.children.find((elt) => elt.name === cs[0]);
  if (!nextNode) {
    nextNode = { name: cs[0], value: 0 };
    flamegraph.children.unshift(nextNode);
  }
  cs.shift();
  // Treatment of the next node
  addNodeToFlamegraph(nextNode, cs, row);
};

interface EvaFlamegraphProps {
  useScope: boolean;
  flameGraph: Flamegraph;
  size: Size
}

function EvaFlamegraph(props: EvaFlamegraphProps): JSX.Element {
  const { useScope, flameGraph, size } = props;
  const { width, height } = size;
  const [ nodeInfos, setNodeInfos ] = React.useState("");

  const changeScope = (f: Flamegraph): void => {
    States.setCurrentScope(f.kfKey as Ast.decl);
  };

  return (
    <>
      <FlameGraph
        data={flameGraph}
        height={height}
        width={width}
        /* eslint-disable-next-line @typescript-eslint/no-explicit-any */
        onChange={(node:any) => {
          if(useScope) changeScope(node.source);
        }}
        onMouseOver={(_e:Event, nodeInfos:Flamegraph) => {
          const percentage = Math.round(
            10*(nodeInfos.value * 100)/flameGraph.value)/10;
          const value = Math.round(nodeInfos.value*100)/100;
          const infos = (
            nodeInfos.name+" : "+value+"s : "+percentage+"%"
          );
          setNodeInfos(infos);
        }}
        onMouseOut={() => { setNodeInfos(""); }}
      />
      {
        nodeInfos &&
        <div className='flame-details'>
          {nodeInfos}
        </div>
      }
    </>
  );
}

// --- Flamegraph Component ---
export function FlamegraphComponent(): JSX.Element {
  const [useScope, flipUseScope] =
    useFlipSettings("eva.flamegraph.scope", true);
  const model = States.useSyncArrayData(Eva.evaFlamegraph);

  const flameGraph = React.useMemo<Flamegraph | null>(() => {
    if(model.length === 0 ) return null;
    const flame: Flamegraph = {
      name: model[0].funlist.split(":")[0],
      value: 0
    };
    model.forEach(row => {
      const cs = row.funlist.split(":");
      cs.shift();
      addNodeToFlamegraph(flame, cs, row);
    });
    return flame;
  }, [model]);

  const isWaitingForData = !flameGraph || !flameGraph.children;

  return (
    <>
      <Ivette.TitleBar >
        <IconButton
          icon="PIN"
          kind={useScope ? "positive" : "default"}
          onClick={flipUseScope}
          title={useScope ? "Scope change enabled" : "Scope change disabled"}
        />
        <Inset />
        <EvaStatus />
      </Ivette.TitleBar>
      <EvaReady showChildrenForComputingStatus={!isWaitingForData} >
        {
          !isWaitingForData &&
          <AutoSizer key="flamegraph">
            {(size: Size) => (
              <EvaFlamegraph
                useScope={useScope}
                flameGraph={flameGraph}
                size={size}
              />
            )}
          </AutoSizer>
        }
      </EvaReady>
    </>
  );
}

Ivette.registerComponent({
  id: 'fc.eva.flamegraph',
  label: 'Eva Flamegraph',
  title: 'Detailed flamegraph of the Eva analysis',
  children: <FlamegraphComponent />,
});

// --------------------------------------------------------------------------
