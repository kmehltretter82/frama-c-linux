/* --- Generated Frama-C Server API --- */

/** Dive Services
   @packageDocumentation
   @module frama-c/dive
*/

import * as Json from 'dome/data/json'


/** The name of variable of the program */
export interface variableName {
  /** owner function for a local variable */
  funName?: string;
  /** variable name */
  varName: string;
}


/** Retrieve the whole graph */


/** Erase the graph and start over with an empty one */


/** Add a variable to the graph */


/** Add all alarms of the given function */


/** Explore the graph starting from an existing vertex */


/** Show the dependencies of an existing vertex */


/** Hide the dependencies of an existing vertex */
