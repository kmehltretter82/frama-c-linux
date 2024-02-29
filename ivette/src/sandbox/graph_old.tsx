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

/* -------------------------------------------------------------------------- */
/* --- Sandbox Testing of RichText                                        --- */
/* --- Only appears in DEVEL mode.                                        --- */
/* -------------------------------------------------------------------------- */

import React, { useState, useRef, useMemo }
 from 'react';
import { ToolBar } from 'dome/frame/toolbars';
import { Button } from 'dome/controls/buttons';
import { registerSandbox } from 'ivette';
import { v4 as uuidv4 } from 'uuid';
import './sandbox.css';
import { ForceGraph2D, ForceGraph3D }
 from 'react-force-graph';

/* -------------------------------------------------------------------------- */
/* --- Graph Specifications                                               --- */
/* -------------------------------------------------------------------------- */

export interface Attributes {
  label?: string | number;
  title?: string;
  className?: string;
  index?: string;
}

export type Shape = "dot" | "box" | "circle";
export type ArrowType = "--" | "->" | "<-" | "<->";
export type Layout = "2D" | "3D";

export interface Node extends Attributes {

  /** Node identifier (unique). */
  id: number;
  x?: number;
  y?: number;

  /** defaults to `"dot"` */
  shape?: Shape;

}

export interface Edge extends Attributes {

  source: number;
  target: number;

  /** defaults to `"->"` */
  arrowType?: ArrowType;

}

export type Callback = () => void;
export type SelectionCallback = (node: string, evt: React.MouseEvent) => void;
/* -------------------------------------------------------------------------- */
/* --- Graph Component Properties                                         --- */
/* -------------------------------------------------------------------------- */

export interface GraphProps {
  nodes: Node[];
  links: Edge[];

  /**
     Element to focus on.
     The graph is scrolled to make this node visible if necessary.
   */
  selected?: number;
  hover?: number;
  linkSelected?: number | string;
  linkHover?: number | string;

  /** Force recomputing layout. */
  reset?: boolean;

  /**
     Zoom factor.
     Affects the viewport and the dimension of the nodes.
     When the zoom factor becomes to small, labels might be discarded.
   */
  zoom?: {
    k : number,
    x : number,
    y : number
    }


  /** Kayout engine. */
  layout?: Layout;

  /** Invoked when a node is selected. */
  onSelection?: Callback;

  /** Invoked after layout is computed (typically used after a reset). */
  onReady?: Callback;

  /** Whether the Graph shall be displayed or not (defaults to true). */
  display?: boolean;

  /** Styling the Graph main div element. */
  className?: string;

  /** Elements to be inserted right inside the Graph main div element. */
  children?: React.ReactNode;
}
/* -------------------------------------------------------------------------- */
/* --- Sandbox                                                            --- */
/* -------------------------------------------------------------------------- */



function generateUniqueIds(numIds: number): string[] {
  const uniqueIds: string[] = [];
  for (let i = 0; i < numIds; i++) {
    uniqueIds.push(uuidv4());
  }
  return uniqueIds;
}


function Graph(_props: GraphProps): JSX.Element {

  const [graph, setGraph] =   useState<GraphProps>(_props);
  const resetGraph  = _props;

  const fgRef = useRef<ForceGraphMethods>();

  const memoizedGraph = useMemo(
    () => ({
      nodes: graph.nodes,
      links: graph.links
    }),
    [graph.nodes, graph.links]
  );


  const [focus, setFocus] = useState(0);

  // CSS Node
  const [divElement, setDivElement] = useState(document.getElementById('div'));
  const [divElementShadow, setDivElementShadow] =
  useState(document.getElementById('divShadow'));
  const [divElementSelected, setDivElementSelected] =
  useState(document.getElementById('divSelected'));
  const [divElementSelectedShadow, setDivElementSelectedShadow] =
  useState(document.getElementById('divSelectedShadow'));

  // CSS Edge
  const [divEdge, setDivEdge] =
  useState(document.getElementById('divEdge'));
  const [divEdgeSelected, setDivEdgeSelected] =
  useState(document.getElementById('divEdgeSelected'));

  const nodeCanvasObject = useMemo(() => {
    return (node:Node, ctx : CanvasRenderingContext2D) => {

      setDivElement(document.getElementById('div'));
      setDivElementShadow(document.getElementById('divShadow'));
      setDivElementSelected(document.getElementById('divSelected'));
      setDivElementSelectedShadow(
        document.getElementById('divSelectedShadow'));
      if(divElement !== null) {
      const backgroundItem =
      window.getComputedStyle(divElement).backgroundColor;
      const textColor =
      window.getComputedStyle(divElement).color;

      if(node.id === graph.selected || node.id === graph.hover)
      {
        if(divElementSelectedShadow !== null) {
          ctx.shadowColor =
          window.getComputedStyle(divElementSelectedShadow).backgroundColor;
        }

        if(divElementSelected !== null) {
        ctx.fillStyle =
        window.getComputedStyle(divElementSelected).backgroundColor;
        }
      }
      else{
        if(divElementShadow!== null) {
          ctx.shadowColor =
          window.getComputedStyle(divElementShadow).backgroundColor;
        }


        ctx.fillStyle = backgroundItem;
      }
      const widthBox = 30;
      const heightBox = 10;
      ctx.shadowOffsetX = 8;
      ctx.shadowOffsetY = 8;
      ctx.shadowBlur = 10;
      ctx.beginPath();
      ctx.roundRect((node.x?node.x:0) - 9.9, (node.y?node.y:0) - 5.9,
      widthBox, heightBox - 0.5, [2]);
      ctx.fill();


      if(node.id === graph.selected || node.id === graph.hover)
      {

        if(divElementSelected !== null) {
        ctx.fillStyle = window.getComputedStyle(divElementSelected).color;
        }
      }
      else{
        ctx.fillStyle = textColor;
      }

      ctx.font = '4px Sans-Serif';
      ctx.textAlign = "center";
      ctx.fillText(String(node.id), (node.x?node.x:0),
      node.y?node.y:0);



    }
  };
  }, [divElement, divElementSelected,
    graph.hover, divElementShadow, divElementSelectedShadow, graph.selected]);

  const linkCanvasObject = useMemo(() => {
      return (link: Edge, ctx : CanvasRenderingContext2D) =>
      {

        setDivEdge(document.getElementById('divEdge'));
        setDivEdgeSelected(document.getElementById('divEdgeSelected'));

          if(divEdge!== null && divEdgeSelected!==null &&
            divEdgeSelected !==null&& link!== undefined ) {


            if(link.index === graph.linkSelected ||
              link.index === graph.linkHover)
              {
                ctx.strokeStyle =
                window.getComputedStyle(divEdgeSelected).backgroundColor;
                ctx.shadowColor =
                window.getComputedStyle(divEdge).backgroundColor;
                  ctx.beginPath();
                  ctx.moveTo(link.source.x, link.source.y);
                  ctx.lineTo(link.target.x, link.target.y);
                  ctx.stroke();
              }
              else{

                ctx.strokeStyle =
                window.getComputedStyle(divEdge).backgroundColor;
                ctx.shadowColor =
                window.getComputedStyle(divEdgeSelected).backgroundColor;

                ctx.beginPath();
                ctx.moveTo(link.source.x, link.source.y);
                ctx.lineTo(link.target.x, link.target.y);
                ctx.stroke();


              }



          }
        };
    }, [divEdge, divEdgeSelected, graph.linkHover, graph.linkSelected]);

  const linkDirectionalArrowColor = useMemo(() => {
      return  (link: Edge) =>
      link.index === graph.linkSelected ||
      link.index === graph.linkHover ?
      window.getComputedStyle(divElementSelected!).color :
      window.getComputedStyle(divEdge!).backgroundColor;
    }, [divEdge, divElementSelected, graph.linkSelected, graph.linkHover]);



  return (
    <>
      <div id='div' className='sandbox-item-graph'>
        <div id='divShadow' className='sandbox-item-graph-shadow'></div>
        <div id='divSelected' className='sandbox-item-graph-hover-selected'>
        </div>
        <div id='divSelectedShadow'
        className='sandbox-item-graph-shadow-hover-selected'></div>
        <div id='divEdge' className='sandbox-item-graph-edge'></div>
        <div id='divEdgeSelected'
        className='sandbox-item-graph-edge-hover-selected'></div>
      </div>

      <ToolBar>
        <Button icon='DISPLAY' title='Display' onClick={() => setGraph(
        { ...graph, display: !graph.display })}/>

        {graph.layout === '2D' ?
        <Button  title={'3D'} label={'3D'} onClick={() => setGraph(
        { ...graph, layout: '3D' })}/>:
        <Button  title={'2D'} label={'2D'} onClick={() => setGraph(
          { ...graph, layout: '2D' })}/>
        }
        <Button icon='ZOOM.IN' title={'Zoom in'}  onClick={ () => {
           fgRef.current?.zoom(fgRef.current.zoom() + 1);
         }}/>
        <Button icon='ZOOM.OUT' title={'Zoom out'}  onClick={ () => {
           fgRef.current?.zoom(fgRef.current.zoom() - 1);
         }}/>

        <Button icon='PLUS' title={'Add'} onClick={() => {
          const uniqueId = generateUniqueIds(1);
          const lastId = graph.nodes.length;
          const newId = lastId;
          const targetNode = Math.round( Math.random() *(lastId -1));

          setGraph(prevState => ({
          ...prevState,
          nodes: [...prevState.nodes,
            { id: newId,
              index: uniqueId[0],
              label: newId
            }],
          links: [...prevState.links,
            { source: newId, target: targetNode
            }],
         })); }}/>

        <Button icon='MINUS' title={'Delete'} onClick={() => {
            setGraph(prevState => ({
              ...prevState,
              nodes: prevState.nodes.slice(0, -1),
              links: prevState.links.slice(0, -1),
            })); }}
        />

        <Button icon='DIR.EXPAND' title={'Overview'}  onClick={ () => {
          fgRef.current?.zoomToFit(1000, 300); }}/>

        <Button icon='RELOAD' label='Reset' title={'Reset'} onClick={
         () => { setGraph(resetGraph); } }/>
          <Button icon='TRIANGLE.RIGHT' title={'Focus on'}  onClick={ () => {

            fgRef.current?.zoomToFit(500, 0, (node) =>
            node.id === focus);
            }}/>
          <select
            id={"idNode"}

            value={String(focus)}
            onChange={ (event) => {
              return setFocus(Number(event.target.value)); }}
          >
            {graph.nodes.map((node) =>
            <option key={node.id} value={node.id}>— {node.id} —</option> )}

          </select >
          <h3 style ={{ marginRight: '20px', marginLeft: '20px' }}>

          {" Number of items: ".concat(String(graph.nodes.length ))}</h3>
      </ToolBar>

      {graph.display ? graph.layout === '2D' ?

        // Visualisattion 2D
        <ForceGraph2D
          ref={fgRef}

          graphData={memoizedGraph}
          dagLevelDistance={50}
          autoPauseRedraw={true}
          linkDirectionalArrowLength={8}
          linkDirectionalArrowRelPos={0.99}
          d3AlphaDecay={1}
          d3VelocityDecay={1}

          linkCanvasObjectMode={() => 'after'}
          linkCanvasObject={linkCanvasObject}

          nodeCanvasObjectMode={() => 'after'}
          nodeCanvasObject={nodeCanvasObject}

          nodeLabel={'index'}
          enableZoomInteraction={true}
          maxZoom={5}
          minZoom={1}

          onNodeClick={(node) => { setGraph({ ...graph, selected: node.id });
         } }
          onBackgroundClick={() =>
            { setGraph({ ...graph, selected: -1, linkSelected: -1 }); } }

          onNodeHover={(node) => {
            if(node?.id !== graph.hover) {
              setGraph({ ...graph, hover: node?.id } ); } }}

          onLinkClick={(link) =>
            { if(link?.index !== graph.linkSelected) {
            setGraph({ ...graph,  linkSelected: link.index }); } }
          }


          onLinkHover={(link) =>
            { if(link?.index !== graph.linkHover) {

              setGraph({ ...graph,
                linkHover: link? Number(link.index) : undefined
            });
            } }}

          linkDirectionalArrowColor={linkDirectionalArrowColor}
        />:
        // Visualisattion 3D
        <ForceGraph3D

        graphData={memoizedGraph}
        dagLevelDistance={50}
        d3AlphaDecay={1}
        d3VelocityDecay={1}
        linkDirectionalArrowLength={8}
        linkDirectionalArrowRelPos={0.99}


      />:<></>}
    </>
  );
}

// Génération d'un ensemble de N node et N-1 link
function GenRandomTree(N:number):
GraphProps  {
  const uniqueIds = generateUniqueIds(N);
  const arrowTypes: ArrowType[] = ["--", "->", "<-", "<->"];
  return {

    nodes: [...Array(N).keys()].map(i =>
      ({ id: i, index: uniqueIds[i], label: i,
        x: Math.round(Math.random() * 300),
        y: Math.round(Math.random() * 300) })),

    links: [...Array(N).keys()]
    .filter(id => id)
    .map(id => ({
      source: id as number,
      target: Math.round(Math.random() * (id-1)) as number,
      arrowType: arrowTypes[Math.floor(Math.random() * arrowTypes.length)]
    })),
    layout: '2D',
    zoom: { k: 1, x: 0, y: 0 },
    className: 'sandbox-item-graph',
    display: true,

};
}

const initGraph  = GenRandomTree(5);

/*
registerSandbox({
  id: 'sandbox.graph_old',
  label: 'Graph Component',
  children: <Graph {...initGraph}  />,
});
*/



/* -------------------------------------------------------------------------- */
