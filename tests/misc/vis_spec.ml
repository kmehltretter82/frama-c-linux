open Cil_types
open Cil

class pathcrawlerVisitor prj =
  object(self)
    inherit Visitor.frama_c_copy prj

    method! vfunc fundec =
      Format.printf "Considering sspec of function %s@." fundec.svar.vname;
      Format.printf "@[Funspec of %s is@ @['%a'@]@ through visitor@]@."
        fundec.svar.vname
        Printer.pp_funspec fundec.sspec;
      Format.printf "@[It is@ @['%a'@]@ through get_spec@]@."
        Printer.pp_funspec
        (Annotations.funspec (Globals.Functions.get fundec.svar));
      DoChildren

    method! vspec sp =
      Format.printf "Considering vspec of function %s@."
        (Kernel_function.get_name (Option.get self#current_kf));
      (match self#current_func with
       | Some fundec ->
         Format.printf "@[Funspec of %s is@ @['%a'@]@ through visitor@]@."
           fundec.svar.vname
           Printer.pp_funspec sp;
         Format.printf "@[It is@ @['%a'@]@ through get_spec@]@."
           Printer.pp_funspec
           (Annotations.funspec (Globals.Functions.get fundec.svar));
       | None ->
         Format.printf "@[Function prototype;@ Funspec is@ @['%a'@]@]@."
           Printer.pp_funspec sp;
      );
      DoChildren
  end

let startup () =
  ignore(Ast.get ());
  Format.printf "Starting visit@.";
  let prj = File.create_project_from_visitor "pcanalyzer"
      (fun prj -> new pathcrawlerVisitor prj)
  in
  Format.printf "End visit@.";
  Project.set_current prj;
;;

let () = Db.Main.extend startup
