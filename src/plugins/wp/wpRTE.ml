(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let dkey = Wp_parameters.register_category "rte"

type t = {
  name : string ;
  cint : bool ;
  kernel : (unit -> bool) ;
  option : string ;
  status : unit -> RteGen.Generator.status_accessor ;
}

let option name =
  try name = "" || Dynamic.Parameter.Bool.get name ()
  with _ -> false

let status db kf =
  try let (_,_,get) = db () in get kf
  with Failure _ ->
    Wp_parameters.warning ~once:true
      "Missing RTE plug-in: can not generate conditions" ;
    false

let always _ = true

let configure ~update ~generate kf cint rte =
  if not rte.cint || rte.kernel () then
    begin
      (* need RTE guard, but kernel option is set *)
      if not (status rte.status kf) then
        begin
          if option rte.option then
            let msg = if generate then "generate" else "missing" in
            Wp_parameters.debug ~dkey "function %a: %s rte for %s"
              Kernel_function.pretty kf msg rte.name ;
          else
            Wp_parameters.warning ~once:true ~current:false
              "-wp-rte can annotate %s because %s is not set"
              rte.name rte.option ;
          update := true ;
        end
    end
  else if generate then
    match cint with
    | Cint.Machine -> () (* RTE has been set *)
    | Cint.Natural ->
      Wp_parameters.warning ~once:true ~current:false
        "-wp-rte and model nat require kernel to warn against %s" rte.name

let generator =
  [
    { name = "memory access" ;
      kernel = always ; option = "-rte-mem" ; cint = false ;
      status = (fun () -> RteGen.Generator.Mem_access.accessor) } ;
    { name = "division by zero" ;
      kernel = always ; option = "-rte-div" ; cint = false ;
      status = (fun () -> RteGen.Generator.Div_mod.accessor) } ;
    { name = "signed overflow" ; cint = true ;
      kernel = Kernel.SignedOverflow.get ; option = "" ;
      status = (fun () -> RteGen.Generator.Signed_overflow.accessor) } ;
    { name = "unsigned overflow" ; cint = true ;
      kernel = Kernel.UnsignedOverflow.get ; option = "" ;
      status = (fun () -> RteGen.Generator.Unsigned_overflow.accessor) } ;
    { name = "signed downcast" ; cint = true ; option = "" ;
      kernel = Kernel.SignedDowncast.get ;
      status = (fun () -> RteGen.Generator.Signed_downcast.accessor) } ;
    { name = "unsigned downcast" ; cint = true ; option = "" ;
      kernel = Kernel.UnsignedDowncast.get ;
      status = (fun () -> RteGen.Generator.Unsigned_downcast.accessor) } ;
    { name = "invalid bool value" ; cint = false ;
      option = "-warn-invalid-bool" ;
      kernel = Kernel.InvalidBool.get ;
      status = (fun () -> RteGen.Generator.Bool_value.accessor) } ;
  ]

let generate model kf =
  let update = ref false in
  let cint = WpContext.on_context (model,WpContext.Kf kf) Cint.current () in
  List.iter (configure ~update ~generate:true kf cint) generator ;
  if !update then
    let flags = { (RteGen.Flags.default ()) with pointer_alignment = false } in
    RteGen.Visit.annotate ~flags kf

let generate_all model =
  Wp_parameters.iter_kf (generate model)

let missing_guards model kf =
  let update = ref false in
  let cint = WpContext.on_context (model,WpContext.Kf kf) Cint.current () in
  List.iter (configure ~update ~generate:false kf cint) generator ;
  !update

(* -------------------------------------------------------------------------- *)
