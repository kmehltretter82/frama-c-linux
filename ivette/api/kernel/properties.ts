/* --- Generated Frama-C Server API --- */

/** Property Services
   @packageDocumentation
   @module frama-c/kernel/properties
*/

import * as Json from 'dome/data/json'
import { tag } from 'api/kernel/data';
import { source } from 'api/kernel/services';


/** Property Kinds */
export enum propKind {
  /** Contract behavior */
  behavior = 'behavior';
  /** Complete behaviors clause */
  complete = 'complete';
  /** Disjoint behaviors clause */
  disjoint = 'disjoint';
  /** Clause `@assumes` */
  assumes = 'assumes';
  /** Function precondition */
  requires = 'requires';
  /** Instance of a precondition at a call site */
  instance = 'instance';
  /** Clause `@breaks` */
  breaks = 'breaks';
  /** Clause `@continues` */
  continues = 'continues';
  /** Clause `@returns` */
  returns = 'returns';
  /** Clause `@exits` */
  exits = 'exits';
  /** Function postcondition */
  ensures = 'ensures';
  /** Function termination clause */
  terminates = 'terminates';
  /** Function allocation */
  allocates = 'allocates';
  /** Clause `@decreases` */
  decreases = 'decreases';
  /** Function assigns */
  assigns = 'assigns';
  /** Functional dependencies in function assigns */
  froms = 'froms';
  /** Assertion */
  assert = 'assert';
  /** Check */
  check = 'check';
  /** Loop invariant */
  invariant = 'invariant';
  /** Clause `@loop assigns` */
  loop-assigns = 'loop-assigns';
  /** Loop termination argument */
  variant = 'variant';
  /** Clause `@loop allocates` */
  loop-allocates = 'loop-allocates';
  /** Clause `@loop pragma` */
  loop-pragma = 'loop-pragma';
  /** Reachable statement */
  reachable = 'reachable';
  /** Statement contract */
  code-contract = 'code-contract';
  /** Generalized loop invariant */
  code-invariant = 'code-invariant';
  /** Type invariant */
  type-invariant = 'type-invariant';
  /** Global invariant */
  global-invariant = 'global-invariant';
  /** Axiomatic definitions */
  axiomatic = 'axiomatic';
  /** Logical axiom */
  axiom = 'axiom';
  /** Logical lemma */
  lemma = 'lemma';
  /** ACSL extension `<clause>` */
  ext:<clause> = 'ext:<clause>';
  /** ACSL loop extension `loop <clause>` */
  loop-ext:<clause> = 'loop-ext:<clause>';
  /** Plugin Specific properties */
  prop:<prop> = 'prop:<prop>';
}


/** Returns all registered tags for the above type. */


/** Property Status (consolidated) */
export enum propStatus {
  /** Unknown status */
  unknown = 'unknown';
  /** Unknown status (never tried) */
  never_tried = 'never_tried';
  /** Inconsistent status */
  inconsistent = 'inconsistent';
  /** Valid property */
  valid = 'valid';
  /** Valid (under hypotheses) */
  valid_under_hyp = 'valid_under_hyp';
  /** Valid (external assumption) */
  considered_valid = 'considered_valid';
  /** Invalid property (counter example found) */
  invalid = 'invalid';
  /** Invalid property (under hypotheses) */
  invalid_under_hyp = 'invalid_under_hyp';
  /** Dead property (but invalid) */
  invalid_but_dead = 'invalid_but_dead';
  /** Dead property (but valid) */
  valid_but_dead = 'valid_but_dead';
  /** Dead property (but unknown) */
  unknown_but_dead = 'unknown_but_dead';
}


/** Returns all registered tags for the above type. */


/** Alarm Kinds */
export enum alarms {
  /** Integer division by zero */
  division_by_zero = 'division_by_zero';
  /** Invalid pointer dereferencing */
  mem_access = 'mem_access';
  /** Array access out of bounds */
  index_bound = 'index_bound';
  /** Invalid pointer computation */
  pointer_value = 'pointer_value';
  /** Invalid shift */
  shift = 'shift';
  /** Invalid pointer comparison */
  ptr_comparison = 'ptr_comparison';
  /** Operation on pointers within different blocks */
  differing_blocks = 'differing_blocks';
  /** Integer overflow or downcast */
  overflow = 'overflow';
  /** Overflow in float to int conversion */
  float_to_int = 'float_to_int';
  /** Unsequenced side-effects on non-separated memory */
  separation = 'separation';
  /** Overlap between left- and right-hand-side in assignment */
  overlap = 'overlap';
  /** Uninitialized memory read */
  initialization = 'initialization';
  /** Read of a dangling pointer */
  dangling_pointer = 'dangling_pointer';
  /** Non-finite (nan or infinite) floating-point value */
  is_nan_or_infinite = 'is_nan_or_infinite';
  /** NaN floating-point value */
  is_nan = 'is_nan';
  /** Pointer to a function with non-compatible type */
  function_pointer = 'function_pointer';
  /** Uninitialized memory read of union */
  initialization_of_union = 'initialization_of_union';
  /** Trap representation of a _Bool lvalue */
  bool_value = 'bool_value';
}


/** Returns all registered tags for the above type. */


/** Status of Registered Properties */


/** Signal for array [`status`](#status)  */


/** Data rows for array [`status`](#status)
 */
export interface statusRow {
  /** Entry identifier. */
  key: Json.Key<'status'>;
  /** Full description */
  descr: string;
  /** Kind */
  kind: propKind;
  /** Names */
  names: string[];
  /** Status */
  status: propStatus;
  /** Function */
  function?: Json.Key<'fct'>;
  /** Instruction */
  kinstr?: Json.Key<'stmt'>;
  /** Position */
  source: source;
  /** Alarm name (if the property is an alarm) */
  alarm?: string;
  /** Alarm description (if the property is an alarm) */
  alarm_descr?: string;
  /** Predicate */
  predicate?: string;
}


/** Data fetcher for array [`status`](#status)
 */


/** Force full reload for array [`status`](#status)
 */
