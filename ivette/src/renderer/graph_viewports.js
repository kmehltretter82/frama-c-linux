// --------------------------------------------------------------------------
// --- Graph Visualizations
// --------------------------------------------------------------------------

/** @module dome/graph/viewports */

import React, { useRef, useState, useEffect } from 'react' ;
import Cytoscape from 'cytoscape' ;

export function Graph(props) {
  const container = useRef(null);

  function mount() {
    container.current && props.data?._mount(container.current);
  }

  function unmount() {
    container.current && props.data?._unmount(container.current);
  }

  useEffect(() => {
    mount();
    return unmount;
  });

  return (<div ref={container} style={{ width:'100%', height: '100%' }} />);
}
