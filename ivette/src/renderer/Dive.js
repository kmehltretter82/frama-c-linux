import React, { useState } from 'react';
import Dome from 'dome';
import * as Server from 'frama-c/server';
import * as States from 'frama-c/states';

import { Vfill } from 'dome/layout/boxes';
import { Graph } from './graph_viewports';
import { Component } from 'frama-c/LabViews';
import { Data } from './graph_elements';

import Tippy from 'tippy.js'
import "tippy.js/dist/tippy.css";
import "tippy.js/themes/light-border.css";
import 'tippy.js/animations/shift-away.css';
import "./dive_tippy.css";

import "@fortawesome/fontawesome-free/js/all.js";

import style from './dive_style.js';
import layouts from './dive_layouts.js';


function parseVariable(variable_name) {
  let re = new RegExp(/^((\w+)::)?(\w+)$/);
  let result = re.exec(variable_name);
  if (result) {
    if (result[2])
      return {fun:result[2], var:result[3]};
    else
      return {var:result[3]};
  }
  return null;
}

function callstack_to_string(callstack)
{
  return callstack.map(cs => cs['fun'] + ':' + cs['instr']).join('/');
}

function node_to_interval_string(node)
{
  let data = node.data();
  let interval;

  if (data.float_values) {
    interval = data.float_values.computed;
  }
  else if (data.int_values) {
    interval = data.int_values.computed;
  }

  return "[" + interval.min + " ; " + interval.max + "]";
}

function range(interval, limit)
{
  let l = Math.max(Math.abs(limit.min), Math.abs(limit.max));
  let x = Math.max(Math.abs(interval.min), Math.abs(interval.max));

  if (x == Infinity) {
    return 100;
  }
  else if (x <= Math.E)  {
    return 1;
  }
  else {
    let r = Math.log(Math.log(x)) / Math.log(Math.log(l));
    console.assert(0.0 <= r && r <= 1.0);
    return Math.max(1, Math.min(100, Math.floor(r * 100)));
  }
}


class Dive {
  constructor() {
    this.layout = "cose-bilkent";
    this.graph = new Data({style, autounselectify: false});
    this.cy = this.graph._cy;

    this.setupSelection();
    this.setupCtxMenu();
  }

  setupSelection() {
    /* when a node is selected, also select neighbor edges */
    this.cy.on('select', 'node', (event) => {
      var node = event.target;
      node.neighborhood('edge').select();
      this.explore(node);
    });
  }

  setupCtxMenu() {
    this.graph.onmount = () =>
    {
      this.cy.cxtmenu({
        selector: 'node',
        commands: ele => {
          let data = ele.data();
          let commands = [{
            content: '<span class="fas fa-binoculars fa-2x"></span><br/>Explore',
            select: (ele) => this.explore(ele)
          }];
          if (data.kind == 'composite') {
            commands.push({
              content: '<span class="fa fa-expand-arrows-alt fa-2x"></span><br/>Unfold',
              select: (ele) => {},
              enabled: false
            })
          }
          else {
            commands.push({content:"", enabled: false});
            /*
            commands.push({
              content: '<span class="fa fa-compress-arrows-alt fa-2x"></span><br/>Fold',
              select: (ele) => {},
              enabled: false
            })*/
          }
          if (!data.explored) {
            commands.push({
              content: '<span class="fa fa-eye fa-2x"></span><br/>Show',
              select: (ele) => this.show(ele),
              enabled: true
            })
          }
          else {
            commands.push({
              content: '<span class="fa fa-eye-slash fa-2x"></span><br/>Hide',
              select: (ele) => this.hide(ele),
              enabled: true
            })
          }
          return commands;
        }
      });
    }
  }

  remove(node) {
    let parent = node.parent();
    node.remove();
    if (parent.nonempty() && parent.children().empty())
      this.remove(parent); // Recursively remove parents
  }

  referenceFile(file_name) {
    let id = 'file_' + file_name;
    let node = this.cy.$id(id);
    if (node.nonempty()) {
      return node;
    }
    else {
      return this.cy.add({data:{id, label:file_name}, classes:['file']});
    }
  }

  referenceCallstack(callstack) {
    if (callstack.length == 0)
      return null;

    let name = callstack_to_string(callstack);
    let id = 'callstack_' + name;
    let node = this.cy.$id(id);
    if (node.nonempty()) {
      return node;
    }
    else {
      let elt = callstack.shift();
      let parent_node = this.referenceCallstack(callstack);
      let parent = parent_node ? parent_node.id() : null;
      let label = elt["fun"];
      return this.cy.add({data:{id, label, parent}, classes:['function']});
    }
  }

  createTips(node) {
    let common = {
      interactive: true,
      multiple: true,
      animation: 'shift-away',
      duration: 500,
      trigger: 'manual',
      appendTo: document.body,
      lazy: false,
      onCreate: instance => {
        instance.popperInstance.reference = node.popperRef();
    }};

    let tips = [];

    if (node.data().float_values || node.data().int_values) {
      tips.push(new Tippy(this.cy.container(), {
        ...common,
        content: node_to_interval_string(node),
        placement: 'top',
        distance: 10,
        arrow: true,
      }));
    }

    if (node.data().type) {
      tips.push(new Tippy(this.cy.container(), {
        ...common,
        content: node.data().type,
        placement: 'bottom',
        distance: 20,
        theme: 'light-border',
        arrow: false
      }));
    }

    return tips;
  }

  addTips(node, options) {
    let timeout = null, tips = undefined;

    // Create tips lazily
    node.on('mouseover', () => {
      if (tips == undefined)
        tips = this.createTips(node);
      clearTimeout(timeout);
      timeout = setTimeout(() => tips?.forEach(tip => { tip.show() }), 200);
     });

    node.on('mouseout', () => {
      clearTimeout(timeout);
      timeout = setTimeout(() => tips?.forEach(tip => { tip.hide() }), 1000);
    });
  }

  receiveData(data)
  {
    this.cy.startBatch();

    for (let node_id of data.sub)
    {
      let node = this.cy.$id(node_id);
      this.remove(node);
    }

    let added_eles = null;

    for (let node of data.add.nodes)
    {
      if (node.float_values) {
        let interval = node.float_values.computed;
        let limits = node.float_values.limits;
        node.float_range = range(interval, limits);
        node.grade = node.float_values.grade;
      }
      else if (node.int_values) {
        let interval = node.int_values.computed;
        let limits = node.int_values.limits;
        node.int_range = range(interval, limits);
        node.grade = node.int_values.grade;
      }

      let previous = this.cy.$id(node.id);
      if (previous.nonempty()) {
        previous.removeData();
        previous.data(node);
        previous.neighborhood('edge').remove();
      }
      else {
        let parent = null;
        if (node.locality['callstack'])
          parent = this.referenceCallstack(node.locality['callstack']).id();
        else
          parent = this.referenceFile(node.locality['file']).id();

        let ele = this.cy.add({data: {...node, parent}});
        this.addTips(ele);
        added_eles = this.cy.add(ele).union(added_eles);
      }
    }

    for (let dep of data.add.deps)
    {
      let classes = [ dep.kind ];
      var ele = this.cy.add({
          data:{id:dep.id, source:dep.src, target:dep.dst},
          group:'edges'
        });
      added_eles = this.cy.add(ele).union(added_eles);
    }

    this.cy.endBatch();

    if (added_eles) {
      this.recomputeLayout();
    }
  }

  get layout() {
    return this.layoutName;
  }

  set layout(layoutName) {
    let extended_options = {};
    if (layoutName in layouts)
      extended_options = layouts[layoutName];
    this.layoutOptions = {
      name: layoutName,
      fit: true,
      animate: true,
      randomize: true, /* Not all layouts supports that */
      ...extended_options
    };
  }

  recomputeLayout() {
    this.graph.layout(this.layoutOptions);
  }

  exec(endpoint, params) {
    Server.EXEC({
      endpoint,
      params,
    }).then(data => {
      if (data)
        this.receiveData(data);
    }).catch(err => {
      console.error(err)
    });
  }

  clear() {
    this.cy.elements().remove();
    this.exec("dive.clear", null);
  }

  addVariable(variable) {
    this.exec("dive.add_var", variable);
  }

  addFunctionAlarms(function_name) {
    this.exec("dive.add_function_alarms", function_name);
  }

  explore(node) {
    let id = parseInt(node.id());
    if (id)
      this.exec("dive.explore", id);
  }

  show(node) {
    let id = parseInt(node.id());
    if (id)
      this.exec("dive.show", id);
  }

  hide(node) {
    let id = parseInt(node.id());
    if (id)
      this.exec("dive.hide", id);
  }
}


export default () => {
  const [dive, setDive] = useState(() => new Dive());
  const [selection,] = States.useSelection();
  const fun = selection?.current?.function;
  const marker = selection?.current?.marker;
  const markers = States.useSyncArray('kernel.ast.markerKind');

  React.useEffect(() => {
    if (marker) {
      const mark = markers[marker];
      if (mark && mark.kind === 'variable') {
        const variable = {fun: fun, var: mark.name};
        dive.addVariable(variable);
      }
    }
  }, [fun, marker, markers]);

  return (
    <Component
      id="dive.graph"
      label="Imprecision graph"
      title="Imprecision graph"
    >
      <Vfill>
        <form onSubmit={event => {
            let variable = parseVariable(event.target.variable.value);
            variable && dive.addVariable(variable);
            event.preventDefault();
          }}>
          <input type="text" defaultValue="fb_122_RecdXout::ffn" name="variable" />
          <button>Find Variable</button>
        </form>
        <form onSubmit={event => {
            dive.addFunctionAlarms(event.target.function.value);
            event.preventDefault();
          }}>
          <input type="text" defaultValue="main" name="function" />
          <button>Find Alarms</button>
        </form>
        <form onSubmit={event => {
          dive.clear();
          event.preventDefault();
        }}>
          <button>Clear graph</button>
        </form>
        <label>
          Layout:
          <select defaultValue="{dive.layout}" onChange={event => {
            dive.layout = event.target.value;
            dive.recomputeLayout();
          }}>
            <option value="cose-bilkent">cose-bilkent</option>
            <option value="dagre">dagre</option>
            <option value="cola">cola</option>
            <option value="klay">klay</option>
          </select>
        </label>
        <Graph data={dive.graph}/>
      </Vfill>
    </Component>);
}
