open Cil_types

let dump_to_string fundec =
  Options.Self.feedback "Computing CFG for function %s"
    (fundec.svar.vorig_name);
  ignore
    (Visitor.visitFramacFunction
       (new Visit.print_cfg Format.str_formatter) fundec);
  Format.flush_str_formatter ()

module Cfg_graph_state = State_builder.Hashtbl
    (Cil_datatype.Fundec.Hashtbl)
    (Datatype.String)
    (struct
      let name = "Dump.Cfg_graph_state"
      let dependencies = [ Ast.self; Eva.Analysis.self ]
      let size = 17
    end)

let dump_to_string_memoized = Cfg_graph_state.memo dump_to_string

let dump_function fundec fmt =
  Format.fprintf fmt "digraph %s {\n%s\n}\n"
    fundec.svar.vorig_name
    (dump_to_string_memoized fundec)
