// --------------------------------------------------------------------------
// --- Graph Elements
// --------------------------------------------------------------------------

/** @module dome/graph/elements */

import Cytoscape from 'cytoscape' ;
import './graph_libs'

const defaultStyle = [
  {
    selector: 'node',
    style: {
      'background-color': '#666',
      'label': 'data(label)'
    }
  },
  {
    selector: 'edge',
    style: {
      'width': 3,
      'line-color': '#ccc',
      'target-arrow-color': '#ccc',
      'target-arrow-shape': 'triangle'
    }
  }
];

// --------------------------------------------------------------------------

/**
   @summary Collection of edges and vertices
   @description

*/

export class Data {
  onmount = undefined;

  constructor(options = {}) {
    this._cy = Cytoscape({style: defaultStyle, ...options});
    this._engine = { name: 'preset' };
    this._kid = 0 ;
  }

  fresh() { return 'dome#' + (++this._kid) ; }

  layout(options) {
    if (!this._layout || options) {
      if (options) this._engine = options ;
      this._layout = this._cy.layout(this._engine);
    }
    this._layout.run();
  }

  addNode( data , options={} )
  {
    if (!data.id) data.id = this.fresh();
    if (!data.label) data.label = "" ;
    this._cy.add({ ...options , group: 'nodes', data });
    this._layout = undefined ;
    return data.id ;
  }

  addEdge( data , options={} )
  {
    if (!data.id) data.id = this.fresh();
    this._cy.add({ ...options , group: 'edges', data });
    this._layout = undefined ;
    return data.id ;
  }

  // Private: only used by DOME
  _mount( divRef ) {
    if (divRef) {
      this._cy.mount(divRef);
      this.onmount && this.onmount();
    }
    this.layout();
  }

  // Private: only used by DOME
  _unmount( divRef ) {
    if (divRef === this._cy.container) this._cy.unmount();
  }

}

// --------------------------------------------------------------------------

export default { Data };

// --------------------------------------------------------------------------
