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
import {
  NodeObject as NodeObject3D,
} from 'react-force-graph-3d';

import * as Ivette from 'ivette';

import * as Dome from 'dome';
import {
  Graph, IGraphOptions3D, ILinksOptions, INodesOptions
} from 'dome/graph/graph';
import { Icon } from 'dome/controls/icons';
import * as Themes from 'dome/themes';
import { Decoder, Encoder, json, JsonTypeError } from 'dome/data/json';
import { useWindowSettingsData } from 'dome/data/settings';

import * as Server from 'frama-c/server';
import { computeFcts, useFunctionFilter } from 'frama-c/kernel/Globals';
import * as Ast from 'frama-c/kernel/api/ast';
import * as Properties from 'frama-c/kernel/api/properties';
import * as States from 'frama-c/states';
import * as Eva from 'frama-c/plugins/eva/api/general';
import {
  callGraphFunction, SelectedNodes, ModeDisplay,
  CGNode, CGLink, CGData,
  CallGraphFunc, SelectedNodesData
} from "frama-c/plugins/callgraph/definitions";

import './callgraph.css';
import * as Node from "./components/node";
import { Panel } from './components/panel';
import { CallgraphToolsBar } from "./components/toolbar";
import { IThreeStateButton } from "./components/threeStateButton";
import { CallgraphTitleBar } from "./components/titlebar";

import * as CgAPI from './api';

// --------------------------------------------------------------------------
// --- Graph functions
// --------------------------------------------------------------------------

function convertGraph(
  graph: CgAPI.graph | undefined,
  functionStats: Eva.functionStatsData[],
  properties: Properties.statusData[],
  evaps: Eva.propertiesData[],
): CGData
{
  const nodes: CGNode[] = [];
  const links: CGLink[] = [];

  const getScopeTaint = (id: Ast.decl): States.Tag[] => {
    const taint: States.Tag[] = [];

    properties.filter((elt) => elt.scope === id).forEach((elt) => {
      const n = evaps.find((ps) => ps.key === elt.key);
      taint.push(({ name: n?.taint || "not_computed" }));
    });
    return taint;
  };

  if (graph) {
    for (const v of graph.vertices) {
      const stats = functionStats.find((elt) => elt.key === v.decl);
      const scopeTaint = getScopeTaint(v.decl);
      const node: CGNode = {
        id: v.decl,
        label: v.name,
        alarmCount: stats?.alarmCount,
        alarmStatuses: stats?.alarmStatuses,
        coverage: stats?.coverage,
        taintStatus: scopeTaint
      };
      nodes.push(node);
    }
    for (const e of graph.edges) {
      // Check if is recursive function
      if (e.src === e.dst) {
        nodes[nodes.findIndex((elt) => elt.id === e.src)].isRecursive = true;
      } else {
        const link: CGLink = { source: e.src, target: e.dst };
        links.push(link);
      }
    }
  }
  return { nodes, links };
}

function filterGraph(graph?: CgAPI.graph, ids: string[] = []): CgAPI.graph {
  if (!graph) return { vertices: [], edges: [] };
  return {
    vertices: graph.vertices.filter(elt => ids.includes(elt.decl)),
    edges: graph.edges.filter(elt =>
      Boolean(ids.includes(elt.src) && ids.includes(elt.dst)))
  };
}

/* -------------------------------------------------------------------------- */
/* --- Callgraph component                                                --- */
/* -------------------------------------------------------------------------- */

function Callgraph(): JSX.Element {
  const isComputed = States.useSyncValue(CgAPI.isComputed);
  if(isComputed === false) Server.send(CgAPI.compute, null);

  const graph = States.useSyncValue(CgAPI.callgraph);
  const alarms = States.useSyncArrayData(Eva.functionStats);

  /** Function list and properties */
  const ker = States.useSyncArrayProxy(Ast.functions);
  const eva = States.useSyncArrayProxy(Eva.functions);
  const functions = React.useMemo(() => computeFcts(ker, eva), [ker, eva]);
  const properties = States.useSyncArrayData(Properties.status);
  const evaps = States.useSyncArrayData(Eva.properties);
  const functionFilter = useFunctionFilter();

  const {
    contextMenuItems, multipleSelection, showFunction
  } = functionFilter;

  const filteredFunctions =  React.useMemo(() => {
    const test = functions ? functions.filter(showFunction) : [];
    return test;
  }, [functions, showFunction]);

  /** Current location */
  const { scope } = States.useCurrentLocation();

  /** Specific nodes*/
  const selectedFunctions = React.useMemo<Set<string>>(() => {
    return new Set(multipleSelection.map(elt => elt as string));
  }, [multipleSelection]);

  const taintedFunctions =  React.useMemo(() => {
    const scope: string[] = [];
    evaps.forEach((ps) => {
      if(ps.taint === "direct_taint" || ps.taint === "indirect_taint") {
        const prop = properties.find((elt) => elt.key === ps.key);
        if(prop && prop.scope && !scope.includes(prop.scope))
          scope.push(prop.scope);
      }
    });
    return scope;
  }, [properties, evaps]);

  const unprovenPropertiesFunctions = React.useMemo<Set<string>>(() => {
    const ids: SelectedNodesData = new Set();
    alarms.forEach(elt => {
      if (elt.alarmCount.length > 0) ids.add(elt.key);
    });
    return ids;
  }, [alarms]);

  /** Graph */
  const filteredGraph = React.useMemo<CgAPI.graph>(() => {
    return filterGraph(graph, filteredFunctions.map(elt => elt.decl));
  }, [graph, filteredFunctions]);

  const graphData = React.useMemo<CGData>(() => {
    return convertGraph(filteredGraph, alarms, properties, evaps);
  }, [filteredGraph, alarms, properties, evaps]);

  const [selectedNodes, setSelectedNodes] = React.useState<SelectedNodes>({
    tic: false,
    set: new Set<string>()
  });

  /** Control */
  /* eslint-disable max-len */
  const decodeMode: Decoder<ModeDisplay> = (js: json) => {
    if (js === 'all' || js === "linked" || js === "selected" ) return js;
    else throw new JsonTypeError("ModeDisplay", js);
  };
  const [ displayMode, setDisplayMode ] = Dome.useWindowSettings<ModeDisplay>(
    "ivette.callgraph.displaymode", decodeMode, "all"
  );
  const encodeButton: Encoder<IThreeStateButton> = (js: IThreeStateButton) => {
    return JSON.stringify(js);
  };
  const decodeButton: Decoder<IThreeStateButton> = (js: json) => {
    if (typeof js === 'string') return JSON.parse(js);
    else throw new JsonTypeError("string", js);
  };
  const [ selectedParents, setSelectedParents ] =
    useWindowSettingsData<IThreeStateButton>(
      "ivette.callgraph.selectedparents",
      decodeButton, encodeButton,
      { active: true, max: true, value: 1 }
  );
  const [ selectedChildren, setSelectedChildren ] =
    useWindowSettingsData<IThreeStateButton>(
      "ivette.callgraph.selectedChildren",
      decodeButton, encodeButton,
      { active: true, max: true, value: 1 }
  );

  const panelVisibleState = Dome.useFlipSettings("ivette.callgraph.panelVisible", true);
  const [ verticalSpacing, setVerticalSpacing ] = Dome.useNumberSettings("ivette.callgraph.verticalspacing", 75);
  const [ horizontalSpacing, setHorizontalSpacing ] = Dome.useNumberSettings("ivette.callgraph.horizontalspacing", 500);
  const [ autoCenter, flipAutoCenter ] = Dome.useFlipSettings("eva.callgraph.autocenter", true);
  const [ autoSelect, flipAutoSelect ] = Dome.useFlipSettings('eva.callgraph.autoselect', true);
  /* eslint-enable max-len */

  const style = Themes.useStyle();

  const C = React.useMemo<CallGraphFunc>(() => {
    return callGraphFunction(
      [selectedNodes, setSelectedNodes],
       graphData, displayMode, style,
       selectedParents, selectedChildren
    );
  }, [ selectedNodes, setSelectedNodes, graphData, displayMode,
     style, selectedChildren, selectedParents ]);

  const getNode = React.useMemo(() => {
    return (node: NodeObject3D<CGNode>) => {
      return Node.getNode(node, selectedNodes, C.onNodeClickMultiSelect);
    };
  }, [selectedNodes, C.onNodeClickMultiSelect]);

  React.useEffect(() => {
    if(autoSelect && scope)
      setSelectedNodes((elt) => {
        return { tic: !elt.tic, set: new Set([scope]) };
      });
  }, [scope, autoSelect]);

  React.useEffect(() => {
    if(autoSelect && selectedFunctions.size > 0)
      setSelectedNodes((elt) => {
    return { tic: !elt.tic, set: selectedFunctions };
  });
  }, [selectedFunctions, autoSelect]);

  const cycles = React.useRef<string[][]>([]);

  const onDagError = (val: string[]): void => {
    const isAlreadySave = (): boolean => {
      for (const i in cycles.current) {
        if (val.length === cycles.current[i].length) {
          for( const j in cycles.current[i] ) {
            if (cycles.current[i][j] !== val[j]) break;
          }
          return true;
        }
      }
      return false;
    };
    if(!isAlreadySave()) {
      cycles.current.push(val);
      C.updateSelectedNodes(new Set(cycles.current.flat()));
    }
  };

  const nodesOptions: INodesOptions = {
    visibility: (node) => { return C.getNodeVisibility(node.id); },
  };

  const linkOptions: ILinksOptions = {
    width: (link) => { return C.getLinkWidth(link); },
    color: (link) => { return C.getLinkColor(link); },
    visibility: (link) => { return C.getLinkVisibility(link); },
    directionalArrow: 3,
    directionalParticle: 3,
    particleWidth: (link) => { return C.getLinkWidth(link); },
    particleColor: (link) => { return C.getLinkColor(link); },
  };

  const options3D: IGraphOptions3D = {
    backgroundColor: style.getPropertyValue('--background'),
    autoCenter: autoCenter,
    displayMode: 'td',
    depthSpacing: verticalSpacing,
    horizontalSpacing: horizontalSpacing,
    onDagError,
    htmlNode: getNode,
    linkOptions,
    nodesOptions,
  };


  return (
    <>
      <CallgraphTitleBar
        contextMenuItems={contextMenuItems}
        autoCenterState={[ autoCenter, flipAutoCenter ]}
        autoSelectState={[ autoSelect, flipAutoSelect ]}
      />
      <CallgraphToolsBar
        displayModeState={[ displayMode, setDisplayMode ]}
        selectedParentsState={[ selectedParents, setSelectedParents ]}
        selectedChildrenState={[ selectedChildren, setSelectedChildren ]}
        panelVisibleState={panelVisibleState}
        verticalSpacingState={[ verticalSpacing, setVerticalSpacing ]}
        horizontalSpacingState={[ horizontalSpacing, setHorizontalSpacing ]}
        selectedFunctions={selectedFunctions}
        taintedFunctions={taintedFunctions}
        unprovenPropertiesFunctions={unprovenPropertiesFunctions}
        cycleFunctions={cycles.current.flat()}
        dagMode={displayMode}
        updateNodes={C.updateSelectedNodes}
      />

      {!isComputed &&
          <Icon
            id={"SPINNER"}
            className={"cg-graph-computing"}
            size={130}
          />
      }

      {isComputed &&
        <div className='cg-graph-container'>
          <Graph
            layout='3D'
            nodes={graphData.nodes}
            edges={graphData.links}
            selected={undefined}
            options3D={options3D}
          />
          <Panel
            graphData={graphData}
            selectedNodes={selectedNodes}
            tainted={taintedFunctions.length}
            properties={properties}
            evaProperties={evaps}
            style={style}
            panelVisibleState={panelVisibleState}
          />
        </div>
      }

    </>
  );
}

/* -------------------------------------------------------------------------- */
/* --- Register component                                                 --- */
/* -------------------------------------------------------------------------- */

Ivette.registerComponent({
  id: 'fc.callgraph',
  label: 'Call Graph',
  title:
    'Display a graph showing calls between functions.',
  children: <Callgraph />,
});

Ivette.registerView({
  id: 'fc.callgraph',
  label: 'Callgraph',
  layout: {
    ABCD: 'fc.callgraph',
  }
});

// --------------------------------------------------------------------------
