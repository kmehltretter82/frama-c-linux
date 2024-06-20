open Cil_types
open Logic_typing

let () = Format.printf "[test-import] Linking.@."

let loader (ctxt: module_builder) (loc: location) (m: string list) =
  begin
    Format.printf "[test-import:%d] Loading %s.@."
      (fst loc).pos_lnum (String.concat "::" m) ;
    let t = Cil_const.make_logic_type "t" in
    let check = Cil_const.make_logic_info "check" in
    let x = Cil_const.make_logic_var_formal "x" (Ltype(t,[])) in
    let k = Cil_const.make_logic_var_formal "k" Linteger in
    check.l_profile <- [x;k] ;
    ctxt.add_logic_type loc t ;
    ctxt.add_logic_function loc check ;
  end

let register () =
  begin
    Format.printf "[test-import] Registering 'foo'.@." ;
    Acsl_extension.register_module_importer "foo" loader ;
  end

let () = Cmdline.run_after_extended_stage register
