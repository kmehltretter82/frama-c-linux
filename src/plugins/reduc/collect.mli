open Cil_types

type 'a alarm_component = Emitter.t ->
  kernel_function ->
  stmt ->
  rank:int -> Alarms.alarm -> code_annotation -> 'a -> 'a

type env

type varh = VarAll
type annoth = AnnotAll | AnnotInout

val empty_env: varh -> annoth -> env

val get_relevant: env alarm_component (* Set(loc) * Set(exp) ? *)

val should_annotate_stmt: env -> stmt -> bool
val get_relevant_vars_stmt: env -> kernel_function -> stmt -> lval list
