open Cil_types

let dump_to_string fundec =
  Options.Self.feedback "Computing CFG for function %s"
    (fundec.svar.vorig_name);
  ignore
    (Visitor.visitFramacFunction (new Visit.print_cfg Format.str_formatter) fundec);
  Format.flush_str_formatter ()

module Cfg_graph_state = State_builder.Hashtbl
    (Cil_datatype.Fundec.Hashtbl)
    (Datatype.String)
    (struct
      let name = "Dump.Cfg_graph_state"
      let dependencies = [ Ast.self; Eva.Analysis.self ]
      let size = 17
    end)

module Eva_is_computed = State_builder.Ref
    (Datatype.Bool)
    (struct
      let name = "Dump.Eva_is_computed"
      let dependencies = []
      let default () = false
    end)

let dump_to_string_memoized = Cfg_graph_state.memo dump_to_string

let dump_function fundec fmt =
  if not (Eva_is_computed.get ()) && Eva.Analysis.is_computed () then begin
    Eva_is_computed.set true;
    let selection = State_selection.with_dependencies Cfg_graph_state.self in
    Project.clear ~selection ();
  end;
  Format.fprintf fmt "digraph %s {\n%s\n}\n"
    fundec.svar.vorig_name
    (dump_to_string_memoized fundec)
