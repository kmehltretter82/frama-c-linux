open Cil_types

let dump_function fundec fmt =
  Options.Self.feedback "Computing CFG for function %s"
    (fundec.svar.vorig_name);
  Format.fprintf fmt "digraph %s {\n" fundec.svar.vorig_name;
  ignore
    (Visitor.visitFramacFunction (new Visit.print_cfg fmt) fundec);
  Format.fprintf fmt "\n}\n"
