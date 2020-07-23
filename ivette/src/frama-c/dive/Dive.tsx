import React, { useState, useEffect } from 'react';
import _ from 'lodash';
import { renderToString } from 'react-dom/server';
import * as Dome from 'dome';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import * as API from 'api/plugins/dive';

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
  onSelect: ((_: States.Location[]) => void) | null = null;
  selectedLocation: (States.Location | undefined) = undefined;

  constructor(cy: Cytoscape.Core | null = null) {
    this.cy = cy || Cytoscape();
    this.headless = this.cy.container() === null;
    this.cy.elements().remove();
    this.cy.off('click');
    this.cy.on('click', 'node', (event) => this.clickNode(event.target));

    this.layout = 'cose-bilkent';

    if (!this.headless)
      this.setupCtxMenu();

    this.refresh();
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
    let newNodes = this.cy.collection();

    for (const node of data.nodes)
    {
      if (typeof node.range === 'number')
        node.stops = `0% ${node.range}% ${node.range}% 100%`;

      let ele = this.cy.$id(node.id);
      if (ele.nonempty()) {
        ele.removeData();
        ele.data(node);
        ele.neighborhood('edge').remove();
      }
      else {
        let parent = null;
        if (node.locality.callstack)
          parent = this.referenceCallstack(node.locality.callstack)?.id();
        else
          parent = this.referenceFile(node.locality.file).id();

        ele = this.cy.add({ group: 'nodes', data: { ...node, parent } });
        this.addTips(ele);
        newNodes = ele.union(newNodes);
      }

      // Add a node for the user to ask for more dependencies
      const idmore = `${node.id}-more`;
      this.cy.remove(`#${idmore}`);
      if (node.backward_explored === 'partial') {
        const elemore = this.cy.add({
          group: 'nodes',
          data: { id: idmore, parent: ele.data('parent') },
          classes: 'more',
        });
        newNodes = elemore.union(newNodes);
        this.cy.add({
          group: 'edges',
          data: { source: idmore, target: node.id },
        });
      }
    }

    for (const dep of data.deps)
    {
      this.cy.add({
        data: { ...dep, source: dep.src, target: dep.dst },
        group: 'edges',
        classes: dep.kind,
      });
    }

    return newNodes;
  }

  receiveData(data: any): Cytoscape.NodeSingular {
    this.cy.startBatch();

    for (const id of data.sub)
      this.remove(this.cy.$id(id));

    const newNodes = this.receiveGraph(data.add);

    this.cy.endBatch();

    if (newNodes)
      this.recomputeLayout(newNodes);

    return this.cy.$id(data.root);
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
      randomize: false, /* Keep previous positions if layout supports it */
      ...extendedOptions,
    };

    this.recomputeLayout();
  }

  recomputeLayout(newNodes: Cytoscape.Collection = this.cy.collection()): void {
    if (this.layoutOptions && this.cy.container()) {
      /* Animate opacity from 0 to 100 for new elements */
      const newEles = newNodes.union(newNodes.neighborhood('edge'));
      newEles.style('opacity', 0);

      this.cy.layout({
        animationEasing: 'ease-in-out-quad',
        /* Do not move new nodes */
        animateFilter: (node: Cytoscape.Singular) => !newNodes.contains(node),
        /* But make them appear slowly */
        stop: () => newEles.animate({
          style: { opacity: 1.0 },
          duration: 500,
        }),
        ...this.layoutOptions,
      } as unknown as Cytoscape.LayoutOptions).run();
    }
  }

  async exec<In, Out>(
    request: Server.ExecRequest<In, Out>,
    param: In,
  ) {
    try {
      if (Server.isRunning()) {
        await this.setMode();
        const data = await Server.send(request, param);
        if (data)
          return this.receiveData(data);
      }
    }
    catch (err) {
      console.error(err);
    }

    return null;
  }

  async refresh(): Promise<void> {
    try {
      if (Server.isRunning()) {
        const data = await Server.send(API.graph, {});
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
      await Server.send(API.window, window);
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
    this.exec(API.clear, null);
  }

  async add(marker: string) {
    const node = await this.exec(API.add, marker);
    if (node)
      this.selectNode(node);
  }

  explore(node: Cytoscape.NodeSingular): void {
    const id = parseInt(node.id(), 10);
    if (id)
      this.exec(API.explore, id);
  }

  show(node: Cytoscape.NodeSingular): void {
    const id = parseInt(node.id(), 10);
    if (id)
      this.exec(API.show, id);
  }

  hide(node: Cytoscape.NodeSingular): void {
    const id = parseInt(node.id(), 10);
    if (id)
      this.exec(API.hide, id);
  }

  clickNode(node: Cytoscape.NodeSingular): void {
    this.explore(node);

    const writes = node.data()?.writes;
    if (writes)
      this.onSelect?.(writes);

    this.selectNode(node);
  }

  selectLocation(location: States.Location) {
    const selectNode = this.cy.$(':selected');
    const writes = selectNode?.data()?.writes;
    if (location.marker && !_.some(writes, location)) {
      this.add(location.marker);
    }
    else {
      this.selectNode(selectNode); // Update selection
    }
  }

  selectNode(node: Cytoscape.NodeSingular): void {
    const hasOrigin = (ele: Cytoscape.NodeSingular) => (
      _.some(ele.data().origins, this.selectedLocation)
    );
    this.cy.$(':selected').unselect();
    node.select();
    const edges = node.incomers('edge');
    edges.unselect();
    edges.filter(hasOrigin).select();
  }
}

const GraphView = () => {

  // Hooks
  const [dive, setDive] = useState(() => new Dive());
  const [selection, updateSelection] = States.useSelection();
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

  /* When clicking on a node, select its writes locations as a multiple
     selection. If these locations were already selected, select the next
     location in the multiple selection. */
  useEffect(() => {
    dive.onSelect = (locations) => {
      if (updateSelection) {
        if (_.isEqual(locations, selection?.multiple?.allSelections)) {
          updateSelection('MULTIPLE_CYCLE');
        }
        else {
          updateSelection({
            locations,
            index: 0,
          });
        }
      }
    };
  }, [dive, selection, updateSelection]);

  useEffect(() => {
    const index = selection?.multiple?.index;
    const allSelections = selection?.multiple?.allSelections;
    if (allSelections && 0 <= index && index < allSelections.length) {
      const selected = allSelections[index];
      dive.selectedLocation = selected;
    }
  }, [dive, selection]);

  // Updates the graph according to the selected marker.
  useEffect(() => {
    if (!lock && selection?.current) {
      dive.selectLocation(selection?.current);
    }
  }, [dive, lock, selection, selectionMode]);

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
