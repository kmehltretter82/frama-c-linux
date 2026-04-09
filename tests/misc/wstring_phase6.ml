open Cil_types

let print_loc fmt (b,e : Filepos.t * Filepos.t) =
  Format.fprintf fmt "Start line %d, char %d; End line %d, char %d"
    b.pos_lnum (b.pos_cnum - b.pos_bol) e.pos_lnum (e.pos_cnum - e.pos_bol)

class vis =
  object
    inherit Visitor.frama_c_inplace
    method! vexpr e =
      (match e.enode with
       | Lval(Var vi, NoOffset as lv) | StartOf(Var vi, NoOffset as lv)
         when Ast_info.is_string_literal vi ->
         Kernel.result "@[<hov 0>@[<h 0>Constant %a@]@ location: %a@]"
           Printer.pp_lval lv print_loc e.eloc
       | _ -> ());
      Cil.DoChildren
  end

let do_it () = Visitor.visitFramacFileSameGlobals (new vis) (Ast.get())

let () = Boot.Main.extend do_it
