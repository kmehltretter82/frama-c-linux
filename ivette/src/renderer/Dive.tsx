import { strict as assert } from 'assert';

import Cytoscape from 'cytoscape';
import React, { useState } from 'react';
import { renderToString } from 'react-dom/server';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import tippy, * as Tippy from 'tippy.js';
import 'tippy.js/dist/tippy.css';
import 'tippy.js/themes/light-border.css';
import 'tippy.js/animations/shift-away.css';
import './dive_tippy.css';

import { Vfill } from 'dome/layout/boxes';
import { Component } from 'frama-c/LabViews';
import { Data } from './graph_elements';
import { Graph } from './graph_viewports';

import '@fortawesome/fontawesome-free/js/all';

import style from './dive_style';
import layouts from './dive_layouts.json';


const ctxmenu = {
  explore: <div><div className="fas fa-binoculars fa-2x" />Explore</div>,
  unfold: <div><div className="fa fa-expand-arrows-alt fa-2x" />Unfold</div>,
  fold: <div><div className="fa fa-compress-arrows-alt fa-2x" />Fold</div>,
  show: <div><div className="fa fa-eye fa-2x" />Show</div>,
  hide: <div><div className="fa fa-eye-slash fa-2x" />Hide</div>,
};


export interface Callsite {
  readonly fun: string;
  readonly instr: string;
}

export interface Interval {
  readonly min: number;
  readonly max: number;
}

export type callstack = Callsite[];


interface Cy extends Cytoscape.Core {
  cxtmenu(options: any): void;
}


function callstackToString(callstack: callstack): string {
  return callstack.map((cs) => `${cs.fun}:${cs.instr}`).join('/');
}

function nodeToIntervalString(node: Cytoscape.NodeSingular): string
{
  const data = node.data();
  let interval;

  if (data.float_values) {
    interval = data.float_values.computed;
  }
  else if (data.int_values) {
    interval = data.int_values.computed;
  }

  return `[${interval.min} ; ${interval.max}]`;
}

function range(interval: Interval, limit: Interval): number
{
  const l = Math.max(Math.abs(limit.min), Math.abs(limit.max));
  const x = Math.max(Math.abs(interval.min), Math.abs(interval.max));

  if (x === Infinity) {
    return 100;
  }

  if (x <= Math.E) {
    return 1;
  }

  const r = Math.log(Math.log(x)) / Math.log(Math.log(l));
  assert(0.0 <= r && r <= 1.0);
  return Math.max(1, Math.min(100, Math.floor(r * 100)));
}


class Dive {
  cy: Cy;
  graph: Data;
  layoutName = '';
  layoutOptions: object = {};

  constructor() {
    this.layout = 'cose-bilkent';
    this.graph = new Data({ style, autounselectify: false });
    this.cy = (this.graph._cy as Cy);

    this.setupSelection();
    this.setupCtxMenu();
  }

  setupSelection(): void {
    /* when a node is selected, also select neighbor edges */
    this.cy.on('select', 'node', (event) => {
      const node = event.target;
      node.neighborhood('edge').select();
      this.explore(node);
    });
  }

  setupCtxMenu(): void {
    this.graph.onmount = () =>
    {
      this.cy.cxtmenu({
        selector: 'node',
        commands: (ele: Cytoscape.NodeSingular) => {
          const data = ele.data();
          const commands = [{
            content: renderToString(ctxmenu.explore),
            select: () => this.explore(ele),
            enabled: true,
          }];
          if (data.kind === 'composite') {
            commands.push({
              content: renderToString(ctxmenu.unfold),
              select: () => {},
              enabled: false,
            });
          }
          else {
            commands.push({
              content: '',
              select: () => {},
              enabled: false,
            });
          }
          if (!data.explored) {
            commands.push({
              content: renderToString(ctxmenu.show),
              select: () => this.show(ele),
              enabled: true,
            });
          }
          else {
            commands.push({
              content: renderToString(ctxmenu.hide),
              select: () => this.hide(ele),
              enabled: true,
            });
          }
          return commands;
        },
      });
    };
  }

  remove(node: Cytoscape.NodeCollection): void {
    const parent = node.parent();
    node.remove();
    if (parent.nonempty() && parent.children().empty())
      this.remove(parent); // Recursively remove parents
  }

  referenceFile(fileName: string): Cytoscape.NodeSingular {
    const id = `file_${fileName}`;
    const node = this.cy.$id(id);
    if (node.nonempty()) {
      return node;
    }

    return this.cy.add({ data: { id, label: fileName }, classes: 'file' });
  }

  referenceCallstack(callstack: callstack): Cytoscape.NodeSingular | null {
    const name = callstackToString(callstack);
    const elt = callstack.shift();

    if (!elt)
      return null;

    const id = `callstack_${name}`;
    const node = this.cy.$id(id);
    if (node.nonempty()) {
      return node;
    }

    const parentNode = this.referenceCallstack(callstack);
    const parent = parentNode?.id();
    const label = elt.fun;
    return this.cy.add({ data: { id, label, parent }, classes: 'function' });
  }

  createTips(node: Cytoscape.NodeSingular): Tippy.Instance[] {
    const common = {
      interactive: true,
      multiple: true,
      animation: 'shift-away',
      duration: 500,
      trigger: 'manual',
      appendTo: document.body,
      lazy: false,
      onCreate: (instance: Tippy.Instance) => {
        const { popperInstance } = instance;
        if (popperInstance)
          popperInstance.reference = (node as any).popperRef();
      },
    };

    const container = this.cy.container();
    if (!container)
      return [];

    const tips = [];

    if (node.data().float_values || node.data().int_values) {
      tips.push(tippy(container, {
        ...common,
        content: nodeToIntervalString(node),
        placement: 'top',
        distance: 10,
        arrow: true,
      }));
    }

    if (node.data().type) {
      tips.push(tippy(container, {
        ...common,
        content: node.data().type,
        placement: 'bottom',
        distance: 20,
        theme: 'light-border',
        arrow: false,
      }));
    }

    return tips;
  }

  addTips(node: Cytoscape.NodeSingular): void {
    let timeout: NodeJS.Timeout;
    let tips: Tippy.Instance[];

    // Create tips lazily
    node.on('mouseover', () => {
      if (tips === undefined)
        tips = this.createTips(node);
      clearTimeout(timeout);
      timeout = setTimeout(() => tips?.forEach((tip) => { tip.show(); }), 200);
    });

    node.on('mouseout', () => {
      clearTimeout(timeout);
      timeout = setTimeout(() => tips?.forEach((tip) => { tip.hide(); }), 1000);
    });
  }

  /* eslint-disable no-restricted-syntax */
  receiveData(data: any): void
  {
    this.cy.startBatch();

    for (const id of data.sub)
    {
      const node = this.cy.$id(id);
      this.remove(node);
    }

    let addedEles = this.cy.collection();

    for (const node of data.add.nodes)
    {
      if (node.float_values) {
        const { computed, limits } = node.float_values;
        node.float_range = range(computed, limits);
        node.grade = node.float_values.grade;
      }
      else if (node.int_values) {
        const { computed, limits } = node.int_values;
        node.int_range = range(computed, limits);
        node.grade = node.int_values.grade;
      }

      const previous = this.cy.$id(node.id);
      if (previous.nonempty()) {
        previous.removeData();
        previous.data(node);
        previous.neighborhood('edge').remove();
      }
      else {
        let parent = null;
        if (node.locality.callstack)
          parent = this.referenceCallstack(node.locality.callstack)?.id();
        else
          parent = this.referenceFile(node.locality.file).id();

        const ele = this.cy.add({ data: { ...node, parent } });
        this.addTips(ele);
        addedEles = this.cy.add(ele).union(addedEles);
      }
    }

    for (const dep of data.add.deps)
    {
      const ele = this.cy.add({
        data: { id: dep.id, source: dep.src, target: dep.dst },
        group: 'edges',
        classes: dep.kind,
      });
      addedEles = this.cy.add(ele).union(addedEles);
    }

    this.cy.endBatch();

    if (addedEles) {
      this.recomputeLayout();
    }
  }

  get layout(): string {
    return this.layoutName;
  }

  set layout(layoutName: string) {
    let extendedOptions = {};
    if (layoutName in layouts)
      extendedOptions = (layouts as {[key: string]: object})[layoutName];
    this.layoutOptions = {
      name: layoutName,
      fit: true,
      animate: true,
      randomize: true, /* Not all layouts supports that */
      ...extendedOptions,
    };
  }

  recomputeLayout(): void {
    this.graph.layout(this.layoutOptions);
  }

  exec(endpoint: string, params: any): void {
    Server.EXEC({
      endpoint,
      params,
    }).then((data) => {
      if (data)
        this.receiveData(data);
    }).catch((err) => {
      console.error(err);
    });
  }

  clear(): void {
    this.cy.elements().remove();
    this.exec('dive.clear', null);
  }

  addNode(marker: any): void {
    this.exec('dive.add_node', marker);
  }

  explore(node: Cytoscape.NodeSingular): void {
    const id = parseInt(node.id(), 10);
    if (id)
      this.exec('dive.explore', id);
  }

  show(node: Cytoscape.NodeSingular): void {
    const id = parseInt(node.id(), 10);
    if (id)
      this.exec('dive.show', id);
  }

  hide(node: Cytoscape.NodeSingular): void {
    const id = parseInt(node.id(), 10);
    if (id)
      this.exec('dive.hide', id);
  }
}


export default () => {
  const [dive] = useState(() => new Dive());
  const [selection] = States.useSelection();
  const fun = selection?.current?.function;
  const marker = selection?.current?.marker;
  const markers = States.useSyncArray('kernel.ast.markerKind');

  React.useEffect(() => {
    if (marker) {
      const kind = markers[marker]?.kind;
      if (kind === 'variable' || kind === 'lvalue' || kind === 'declaration'
          || kind === 'property') {
        dive.addNode(marker);
      }
    }
  }, [dive, fun, marker, markers]);

  return (
    <Component
      id="dive.graph"
      label="Imprecision graph"
      title="Imprecision graph"
    >
      <Vfill>
        <form onSubmit={(event) => {
          dive.clear();
          event.preventDefault();
        }}
        >
          <button type="button">Clear graph</button>
        </form>
        <div>
          Layout:
          <select
            defaultValue="{dive.layout}"
            onChange={(event) => {
              dive.layout = event.target.value;
              dive.recomputeLayout();
            }}
          >
            <option value="cose-bilkent">cose-bilkent</option>
            <option value="dagre">dagre</option>
            <option value="cola">cola</option>
            <option value="klay">klay</option>
          </select>
        </div>
        <Graph data={dive.graph} />
      </Vfill>
    </Component>
  );
};
