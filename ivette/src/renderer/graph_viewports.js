// --------------------------------------------------------------------------
// --- Graph Visualizations
// --------------------------------------------------------------------------

/** @module dome/graph/viewports */

import React from 'react' ;
import Cytoscape from 'cytoscape' ;

// --------------------------------------------------------------------------

/**
   @summary Component for visualizing 2D-graphs
   @description

   **TO BE COMPLETE***
*/

export class Graph extends React.Component {

  constructor(props) {
    super(props);
    this.container = React.createRef();
  }

  componentDidMount() {
    const div = this.container.current ;
    const data = this.props.data ;
    if (div && data) {
      data.layout();
      data._mount(div);
    }
  }

  componentWillUnmount() {
    const div = this.container.current ;
    const data = this.props.data ;
    if (div && data) data._unmount(div);
  }

  render() {
    return (
      <div className='dome-shape-hvfill'>
        <div ref={this.container} style={{ width:'100%', height: '100%' }} />
      </div>
    );
  }

}

// --------------------------------------------------------------------------

export default { Graph };

// --------------------------------------------------------------------------
