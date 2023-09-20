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

import React, { useEffect } from 'react';

import { IconButton } from 'dome/controls/buttons';
import * as Ivette from 'ivette';

import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import EvaReady from 'frama-c/plugins/eva/EvaReady';
import * as API from './api';
import gearsIcon from '../eva/images/gears.svg';

import './dive.css';

const window = {
  perception: { backward: 3, forward: 0 },
  horizon: { backward: undefined, forward: undefined },
};

async function exec<I, O>(rq: Server.ExecRequest<I, O>, i: I):
    Promise<O | undefined> {
  if (Server.isRunning()) {
    await Server.send(API.window, window);
    return await Server.send(rq, i);
  }

  return undefined;
}

async function requestLocation(location: States.Location):
    Promise<number | undefined> {
  return await exec(API.add, location.marker);
}

async function explore(node: API.node): Promise<null | undefined> {
  return await exec(API.explore, node.id);
}

function isDependency(el: API.element): el is API.dependency {
  return 'dst' in el;
}

function Folder(props: {unfolded: boolean, onclick?: () => void}): JSX.Element {
  return <IconButton
      icon={props.unfolded ? 'MINUS' : 'PLUS'}
      title="Fold / Unfold the dependencies"
      className="folder"
      onClick={props.onclick}
    />;
}

function Exploring(): JSX.Element {
  return <><img src={gearsIcon} className="exploration" />Exploring...</>;
}

type withKey<P> = P & {key: string | number | null}

type TreeNodeProps = {
  label: React.ReactNode,
  unfolded?: boolean,
  onunfold?: () => void,
  children?: withKey<React.ReactElement> | withKey<React.ReactElement>[]
}

function TreeNode(props: TreeNodeProps): JSX.Element {
  const [unfolded, setUnfolded] = React.useState(props.unfolded === true);
  const children =
    props.children ?
      (Array.isArray(props.children) ? props.children : [props.children]) :
      [];

  const toggle = (): void => {
    unfolded === false && props.onunfold && props.onunfold();
    setUnfolded(!unfolded);
  };

  return <div>
    {children.length > 0 ?
      <Folder unfolded={unfolded} onclick={toggle} /> : <></>
    }
    <span>{props.label}</span>
    {unfolded ?
      <ul>
        {children.map((element) => <li key={element.key}>{element}</li>)}
      </ul> :
        null
      }
    </div>;
}

function Node(props: {nodeId: number, unfolded?: boolean}): JSX.Element {
  const graphData = States.useSyncArrayElt(API.graph, `n${props.nodeId}`);
  const graph = States.useSyncArrayData(API.graph);

  if (graphData && 'label' in graphData.element) {
    const node = graphData.element;
    const deps = graph
      .map((data) => data.element)
      .filter(isDependency)
      .filter((d) => d.dst === node.id);

    return <TreeNode
        unfolded={props.unfolded}
        onunfold={() => explore(node)}
        label={node.label}>
          {node.backward_explored ?
            deps.map((element) =>
              <Node nodeId={element.src} key={element.src} />
            ) :
            <Exploring key={null} />
          }
      </TreeNode>;
  }

  return <>Error while building the tree</>;
}

export default function TreeComponent(): JSX.Element {
  const [root, setRoot] = React.useState<number | null>(null);
  const [selection] = States.useSelection();

  useEffect(() => {
    const update = async (): Promise<void> => {
      if (selection.current) {
        const node =  await requestLocation(selection.current);
        root === null && node !== null && node !== undefined && setRoot(node);
      }
    };
    update();
  }, [selection, root]);

  return <>
    <Ivette.TitleBar>
      <IconButton
            icon="TRASH"
            onClick={() => setRoot(null)}
            title="Clear the graph"
          />
    </Ivette.TitleBar>
    <EvaReady>
      {
        root === null ?
          <>Select an expression to investigate</>
        :
          <div className="diveTree">
            <Node nodeId={root} unfolded={true} />
          </div>
      }
    </EvaReady>
  </>;
}
