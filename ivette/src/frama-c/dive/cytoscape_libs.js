/* Currently Cytoscape.use emits an error when a library is already loaded.
This prevents Hot Module Reloading for modules where Cytescope.use is used.
Grouping all Cytoscape plugins registrations here solves the problem. */

import Cytoscape from 'cytoscape' ;

import CytoscapeMenu from 'cytoscape-cxtmenu';
import CytoscapePopper from 'cytoscape-popper';
import CytoscapeLayoutDagre from 'cytoscape-dagre';
import CytoscapeLayoutCola from 'cytoscape-cola';
import CytoscapeLayoutCoseBilkent from 'cytoscape-cose-bilkent';
import CytoscapeLayoutKlay from 'cytoscape-klay';

Cytoscape.use(CytoscapePopper);
Cytoscape.use(CytoscapeMenu);
Cytoscape.use(CytoscapeLayoutDagre);
Cytoscape.use(CytoscapeLayoutCola);
Cytoscape.use(CytoscapeLayoutCoseBilkent);
Cytoscape.use(CytoscapeLayoutKlay);
