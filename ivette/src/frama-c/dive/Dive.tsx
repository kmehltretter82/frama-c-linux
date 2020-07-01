import React, { useState, useEffect } from 'react';
import { renderToString } from 'react-dom/server';
import * as Dome from 'dome';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import Cytoscape from 'cytoscape';
import CytoscapeComponent from 'react-cytoscapejs';
import './cytoscape_libs';

import tippy, * as Tippy from 'tippy.js';
import 'tippy.js/dist/tippy.css';
import 'tippy.js/themes/light-border.css';
import 'tippy.js/animations/shift-away.css';
import './tippy.css';

import { IconButton } from 'dome/controls/buttons';
import { Space } from 'dome/frame/toolbars';
import { Component, TitleBar } from 'frama-c/LabViews';

import '@fortawesome/fontawesome-free/js/all';

import style from './style.json';
import layouts from './layouts.json';


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


interface CytoscapeExtended extends Cytoscape.Core {
  cxtmenu(options: any): void;
}


function callstackToString(callstack: callstack): string {
  return callstack.map((cs) => `${cs.fun}:${cs.instr}`).join('/');
}


export type mode = 'explore' | 'overview';

class Dive {
  headless: boolean;
  cy: Cytoscape.Core;
  mode: mode = 'explore';
  _layout = '';
  layoutOptions: Cytoscape.LayoutOptions | undefined;
  currentSelection: string | null = null;
  onSelect: ((marker: string | null) => void) | null = null;

  constructor(cy: Cytoscape.Core | null = null) {
    this.cy = cy || Cytoscape();
    this.headless = this.cy.container() === null;
    this.cy.elements().remove();
    this.cy.off('click');

    this.layout = 'cose-bilkent';

    if (!this.headless) {
      this.setupSelection();
      this.setupCtxMenu();
    }

    this.refresh();
  }

  setupSelection(): void {
    this.cy.on('click', 'node', (event) => {
      const node = event.target;
      node.select();
      this.explore(node);
    });
  }

  setupCtxMenu(): void {
    (this.cy as CytoscapeExtended).cxtmenu({
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
    const container = this.cy.container();
    if (!container)
      return [];

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

    const tips = [];

    if (node.data().values) {
      tips.push(tippy(container, {
        ...common,
        content: node.data().values,
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
  receiveGraph(data: any): Cytoscape.CollectionReturnValue {
    let newEles = this.cy.collection();

    for (const node of data.nodes)
    {
      if (typeof node.range === 'number')
        node.stops = `0% ${node.range}% ${node.range}% 100%`;

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
        newEles = this.cy.add(ele).union(newEles);
      }
    }

    for (const dep of data.deps)
    {
      const ele = this.cy.add({
        data: { ...dep, source: dep.src, target: dep.dst },
        group: 'edges',
        classes: dep.kind,
      });
      newEles = this.cy.add(ele).union(newEles);
    }

    return newEles;
  }

  receiveData(data: any): void {
    this.cy.startBatch();

    for (const id of data.sub)
      this.remove(this.cy.$id(id));

    const newEles = this.receiveGraph(data.add);

    this.cy.endBatch();

    this.selectNode(this.cy.$id(data.root));

    if (newEles)
      this.recomputeLayout();
  }

  get layout(): string {
    return this._layout;
  }

  set layout(layout: string) {
    let extendedOptions = {};
    if (layout in layouts)
      extendedOptions = (layouts as {[key: string]: object})[layout];
    this._layout = layout;
    this.layoutOptions = {
      name: layout,
      fit: true,
      animate: true,
      randomize: true, /* Not all layouts supports that */
      ...extendedOptions,
    };

    this.recomputeLayout();
  }

  recomputeLayout(): void {
    if (this.layoutOptions && this.cy.container())
      this.cy.layout(this.layoutOptions).run();
  }

  async exec(endpoint: string, params: any): Promise<void> {
    try {
      if (Server.isRunning()) {
        await this.setMode();
        const data = await Server.EXEC({ endpoint, params });
        if (data)
          this.receiveData(data);
      }
    }
    catch (err) {
      console.error(err);
    }
  }

  async refresh(): Promise<void> {
    try {
      if (Server.isRunning()) {
        const data = await Server.GET({ endpoint: 'dive.graph', params: {} });
        await this.receiveGraph(data);
        this.recomputeLayout();
      }
    }
    catch (err) {
      console.error(err);
    }
  }

  static async setWindow(window: any): Promise<void> {
    if (Server.isRunning())
      await Server.SET({ endpoint: 'dive.window', params: window });
  }

  async setMode(): Promise<void> {
    switch (this.mode) {
      case 'explore':
        await Dive.setWindow({
          perception: { backward: 2, forward: 0 },
          horizon: { backward: 3, forward: 1 },
        });
        break;
      case 'overview':
        await Dive.setWindow({
          perception: { backward: 3, forward: 0 },
          horizon: { backward: null, forward: null },
        });
        break;
      default: /* This is useless and impossible if the program is correctly
        typed, but the linter wants it */
    }
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

  selectNode(node: Cytoscape.NodeSingular): void {
    const { writes } = node.data(); // List of localizable for writes
    const index = writes.indexOf(this.currentSelection);
    this.currentSelection = writes[index + 1 in writes ? index + 1 : 0];

    const hasOrigin = (ele: Cytoscape.NodeSingular) => (
      ele.data().origins.includes(this.currentSelection)
    );

    node.select();
    node.incomers('edge').filter(hasOrigin).select();

    this.onSelect?.(this.currentSelection);
  }
}


const GraphView = () => {

  // Hooks
  const [dive, setDive] = useState(() => new Dive());
  const node: React.MutableRefObject<string | undefined> = React.useRef();
  const [selection] = States.useSelection();
  const marker = selection?.current?.marker;
  const markers = States.useSyncArray('kernel.ast.markerKind');
  const [lock, flipLock] = Dome.useSwitch('dive.lock', false);
  const [selectionMode, flipSelectionMode] =
        Dome.useGlobalSetting('dive.selectionMode', 'follow');

  function setCy(cy: Cytoscape.Core) {
    if (cy !== dive.cy)
      setDive(new Dive(cy));
  }

  useEffect(() => {
    setDive(new Dive(dive.cy));
  }, [Dive]); // eslint-disable-line react-hooks/exhaustive-deps

  // Follow mode
  useEffect(() => {
    dive.mode = selectionMode === 'follow' ? 'explore' : 'overview';
  }, [dive, selectionMode]);

  // Updates the graph according to the selected marker.
  useEffect(() => {
    if (!lock && marker && marker !== node.current) {
      node.current = marker;
      dive.addNode(marker);
    }
  }, [dive, lock, marker, markers, selectionMode]);

  // Layout selection
  const selectLayout = (layout?: string) => {
    if (layout) {
      dive.layout = layout;
    }
  };
  const layoutsNames = ['cose-bilkent', 'dagre', 'cola', 'klay'];
  const layoutItem = (id: string) => (
    { id, label: id, checked: (id === dive.layout) }
  );
  const layoutMenu = () => {
    Dome.popupMenu(layoutsNames.map(layoutItem), selectLayout);
  };

  // Selection mode
  const selectMode = (id?: boolean) => id && flipSelectionMode(id);
  const modes =
        [{ id: 'follow', label: 'Follow selection' },
          { id: 'add', label: 'Add selection to the graph' },
        ];
  const checkMode =
        (item: { id: string }) => (
          { checked: item.id === selectionMode, ...item }
        );
  const modeMenu = () => {
    Dome.popupMenu(modes.map(checkMode), selectMode);
  };

  // Component
  return (
    <>
      <TitleBar>
        <IconButton
          icon="LOCK"
          onClick={flipLock}
          kind={lock ? 'negative' : 'positive'}
          title={lock ?
            'Unlock the graph: update the graph with the selection' :
            'Lock the graph: do not update the graph with the selection'}
        />
        <IconButton
          icon="SETTINGS"
          onClick={modeMenu}
          title="Choose the selection mode"
        />
        <IconButton
          icon="DISPLAY"
          onClick={layoutMenu}
          title="Choose the graph layout"
        />
        <Space />
        <IconButton
          icon="TRASH"
          onClick={() => dive.clear()}
          title="Clear the graph"
        />
      </TitleBar>
      <CytoscapeComponent
        stylesheet={style}
        cy={setCy}
        style={{ width: '100%', height: '100%' }}
      />
    </>
  );

};

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="dive.graph"
    label="Imprecision graph"
    title="Imprecision graph"
  >
    <GraphView />
  </Component>
);

// --------------------------------------------------------------------------
