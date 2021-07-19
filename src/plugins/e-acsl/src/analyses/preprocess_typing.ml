let typer_visitor = object
 inherit Visitor.frama_c_inplace

 (* Nothing to type in global annotations *)
 method !vannotation _ = Cil.SkipChildren

 (* Only type the globals that do not come from the Rtl *)
  method !vglob_aux =
    function
    (* library functions and built-ins *)
    | GVarDecl(vi, _) | GVar(vi, _, _)
    | GFunDecl(_, vi, _) | GFun({ svar = vi }, _) when Builtins.mem vi.vname ->
      Options.feedback "ignoring builtin";
      Cil.SkipChildren

    | GVarDecl(vi, _) | GVar(vi, _, _) | GFun({ svar = vi }, _)
      when Misc.is_fc_or_compiler_builtin vi ->
      Options.feedback "ignoring fc_or_compiler_builtin %a" Printer.pp_varinfo vi;
      Cil.SkipChildren
    | g when Rtl.Symbols.mem_global g ->
      Options.feedback "ignoring rtl %a" Printer.pp_global g;
      Cil.SkipChildren

      (* generated function declaration: nothing to do *)
    | GFunDecl(_, vi, _) when Misc.is_fc_stdlib_generated vi ->
      Options.feedback "ignoring stdlib generated";
      Cil.SkipChildren

    (* other globals: nothing to do *)
    | GType _
    | GCompTag _
    | GCompTagDecl _
    | GEnumTag _
    | GEnumTagDecl _
    | GAsm _
    | GPragma _
    | GText _
      -> Cil.SkipChildren

<<<<<<< variant A
    | _ -> Cil.DoChildren
>>>>>>> variant B
  method !vpredicate p =
    Error.generic_handle (Typing.type_named_predicate ~lenv) () p;
    Cil.SkipChildren

  method !vspec spec =
    List.iter (fun b -> (List.iter (fun p -> ignore (Visitor.visitFramacIdPredicate self p)) b.b_assumes)) spec.spec_behavior;
    List.iter (type_requires self (Option.get self#current_kf) (self#current_kinstr)) spec.spec_behavior;
    List.iter (type_post_conditions self (Option.get self#current_kf) self#current_kinstr) spec.spec_behavior;
    Cil.SkipChildren
======= end

 method !vpredicate p = Typing.type_named_predicate p; Cil.DoChildren

end


let type_program ast =
  Visitor.visitFramacFileSameGlobals typer_visitor ast

let type_code_annot annot =
  ignore (Visitor.visitFramacCodeAnnotation typer_visitor annot)
