open Cil_types

let print_stmt out = function
  | Instr i -> Printer.pp_instr out i
  | Return _ -> Format.pp_print_string out "<return>"
  | Goto _ -> Format.pp_print_string out "<goto>"
  | Break _ -> Format.pp_print_string out "<break>"
  | Continue _ -> Format.pp_print_string out "<continue>"
  | If (e,_,_,_) -> Format.fprintf out "if %a" Printer.pp_exp e
  | Switch(e,_,_,_) -> Format.fprintf out "switch %a" Printer.pp_exp e
  | Loop _ -> Format.fprintf out "<loop>"
  | Block _ -> Format.fprintf out "<block>"
  | UnspecifiedSequence _ -> Format.fprintf out "<unspecified sequence>"
  | TryFinally _ | TryExcept _ | TryCatch _ -> Format.fprintf out "<try>"
  | Throw _ -> Format.fprintf out "<throw>"

class print_cfg out = object
  inherit Visitor.frama_c_inplace

  method! vfile _ =
    Format.fprintf out "digraph cfg {\n";
    Cil.DoChildrenPost (fun f -> Format.fprintf out "}\n%!"; f)

  method! vglob_aux g =
    match g with
    | GFun(f,_) ->
      Format.fprintf out "  subgraph cluster_%a {\n" Printer.pp_varinfo f.svar;
      Format.fprintf out "    graph [label=\"%a\"];\n" Printer.pp_varinfo f.svar;
      Cil.DoChildrenPost (fun g -> Format.fprintf out "  }\n"; g)
    | _ -> Cil.SkipChildren

  method! vstmt_aux s =
    let color =
      if Eva.Analysis.is_computed () then
        if Eva.Results.is_reachable s
        then "fillcolor=\"#ccffcc\" style=filled"
        else "fillcolor=pink style=filled"
      else ""
    in
    Format.fprintf out "    s%d [label=%S %s]\n"
      s.sid (Pretty_utils.to_string print_stmt s.skind) color;
    List.iter
      (fun succ -> Format.fprintf out "    s%d -> s%d;\n" s.sid succ.sid)
      s.succs;
    Cil.DoChildren

end
