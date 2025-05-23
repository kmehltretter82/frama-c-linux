/* ************************************************************************ */
/*                                                                          */
/*   SPDX-License-Identifier LGPL-2.1                                       */
/*   Copyright (C)                                                          */
/*   CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   */
/*                                                                          */
/* ************************************************************************ */

// Declare markdown files
declare module '*.md?raw' {
  const content: string;
  export default content;
}

declare module '*.png' {
  const value: string;
  export default value;
}

declare module 'react-flame-graph';
declare module 'react-pivottable/PivotTableUI';
declare module 'three/examples/jsm/renderers/CSS2DRenderer';
declare module 'react-cytoscapejs';
