import React from 'react';
import Dome from 'dome';

import { Vfill } from 'dome/layout/boxes';
import { Graph } from './graph_viewports';
import { Component } from 'frama-c/LabViews';

import Dive from './dive.js'

var dive = new Dive();

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

function eventAddVariable(event) {
  let variable_name = event.target.variable.value;
  let variable = parseVariable(variable_name);
  if (variable)
    dive.addVariable(variable);
  event.preventDefault();
}

function eventAddFunctionAlarms(event) {
  let value = event.target.function.value;
  dive.addFunctionAlarms(value);
  event.preventDefault();
}

function eventClear(event) {
  console.log(dive, event);
  dive.clear();
  event.preventDefault();
}

function eventChangeLayout(event) {
  dive.layout = event.target.value;
  dive.recomputeLayout();
}


const DiveGraph = () => {

  return (
    <Vfill>
      <form onSubmit={eventAddVariable}>
        <input type="text" defaultValue="fb_122_RecdXout::ffn" name="variable" />
        <button>Find Variable</button>
      </form>
      <form onSubmit={eventAddFunctionAlarms}>
        <input type="text" defaultValue="main" name="function" />
        <button>Find Alarms</button>
      </form>
      <form onSubmit={eventClear}>
        <button>Clear graph</button>
      </form>
      <label>
        Layout:
        <select defaultValue="{dive.layout}" onChange={eventChangeLayout}>
          <option value="cose-bilkent">cose-bilkent</option>
          <option value="dagre">dagre</option>
          <option value="cola">cola</option>
          <option value="klay">klay</option>
        </select>
      </label>
      <Graph data={dive.graph}/>
    </Vfill>
  );
}

// --------------------------------------------------------------------------
// --- Export Component
// --------------------------------------------------------------------------

export default () => (
  <Component
    id="dive.graph"
    label="Imprecision graph"
    title="Imprecision graph"
  >
    <DiveGraph />
  </Component>
);

// --------------------------------------------------------------------------
