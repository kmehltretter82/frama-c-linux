(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* ----- Additional -eva-help-* options. ------------------------------------ *)

(* Registers parameter -eva-help-[name] that triggers [print_help] when used.
   Returns the parameter name and description. *)
let register_help ~name ~help ?aliases print_help =
  Parameter_customize.set_group Self.help;
  Parameter_customize.set_cmdline_stage Cmdline.Exiting;
  let module Info = struct
    let option_name = "-eva-help-" ^ name
    let help = help
  end in
  let module Param = Self.False (Info) in
  Cmdline.run_after_exiting_stage
    (fun () -> if Param.get () then print_help () else Cmdline.nop);
  let add_alias = Param.add_aliases ~visible:false ~deprecated:true in
  Option.iter add_alias aliases;
  Param.name, help

let domains_help =
  register_help ~name:"domains" Parameters.print_domains_and_exit
    ~help:"list and description of available analysis domains"

let options_help =
  register_help ~name:"options" (fun () -> Cmdline.plugin_help "eva")
    ~help:"list and description of all Eva parameters"

let log_help =
  register_help ~name:"messages" Self.print_categories_and_exit
    ~help:"help about analysis verbosity and message categories"

let warning_help =
  let print () = Self.pp_all_warn_categories_status (); raise Cmdline.Exit in
  register_help ~name:"warnings" print
    ~help:"help about warnings emitted by Eva"

let builtins_help =
  register_help ~name:"builtins" Builtins.print_builtins_and_exit
    ~help:"list of builtins used to interpret some libc functions"
    ~aliases:["-eva-builtins-list"]

(* ----- Textual output of -eva-help option. ------------------------------- *)

let print_header fmt header = Format.fprintf fmt "@{<bold>%s@}@," header

let main_help = [
  "Goal",
  "Proving the absence of run-time errors. \
   Eva emits an alarm at each program point where it cannot prove the absence \
   of an undefined behavior. It can also prove some user-written annotations.";
  "Domains",
  "Eva uses abstract interpretation to infer various properties about \
   programs via analysis domains. The default domain computes the set of \
   possible values for each program variable. Additional domains can infer \
   relations between variables or more precise memory invariants.";
  "Soundness",
  "Eva captures all possible behaviors of the program execution. \
   If an analysis emits no alarm, then the analyzed program is free of the \
   class of undefined behaviors detected by Eva. \
   However, false alarms may be issued on correct code when the analysis is \
   not precise enough to prove it.";
  "Configuration",
  "While the analysis is automatic, many options are available to finely \
   configure its behavior, guide the analysis towards better results and \
   reach a suitable balance between precision and efficiency."
]

let print_intro fmt =
  let print_paragraph fmt (header, text) =
    Format.fprintf fmt "@[<hov 2>%a: %a@]@,"
      print_header header Format.pp_print_text text
  in
  List.iter (print_paragraph fmt) main_help

(* List of (name, short description) of main Eva parameters. We don't use the
   complete help of these parameters, which are sometimes more verbose. *)
let main_parameters =
  let verbose_default = Parameters.Verbose.get_default () |> string_of_int in
  [
    Parameters.Eva.name, "Run the Eva analysis";
    Kernel.MainFunction.name, "Select the entry point of the analysis";
    Kernel.LibEntry.name,
    "Treat the entry point as a library function and not a complete application";
    Parameters.Domains.name, "Enable additional analysis domains";
    Parameters.Precision.name,
    "Quick configuration of the analysis precision from 0 \
     (fastest but rather imprecise analysis) to 11 \
     (accurate but potentially slow analysis)";
    Parameters.Verbose.name,
    "Quick configuration of the analysis verbosity \
     from 0 (no message) to 11 (most messages). Defaults to " ^ verbose_default;
    Mt_options.Enabled.name,
    "Enable analysis of concurrent programs (experimental)"
  ]

let print_main_parameters fmt =
  let print_parameter (name, descr)=
    Format.fprintf fmt "  %-*s : @[<hov>%a.@]@,"
      14 name Format.pp_print_text descr
  in
  print_header fmt "Main Eva parameters are:";
  List.iter print_parameter main_parameters;
  Format.fprintf fmt
    "@,A typical invocation of Eva looks like: \
     frama-c file.c -eva -eva-precision 2@,\
     Analysis results can be inspected in detail in the Frama-C GUI.@,"

let print_more_help fmt =
  let print_help_parameter (name, descr) =
    Format.fprintf fmt "  %-*s : @[<hov>%a@]@,"
      18 name Format.pp_print_text descr
  in
  print_header fmt "More help is available:";
  List.iter print_help_parameter
    [ domains_help; options_help; log_help; warning_help; builtins_help ];
  Format.fprintf fmt
    "@,The complete user manual is available at \
     @{<underline>https://frama-c.com/download/frama-c-eva-manual.pdf@}"

let print_main_help () =
  let header fmt = Format.fprintf fmt "@{<bold>Help of the Eva plugin.@}" in
  Self.printf ~header "@[<v>@,%t@,%t@,%t@]"
    print_intro print_main_parameters print_more_help;
  raise Cmdline.Exit

(* Print our help message as soon as the value of -eva-help changes, to ensure
   it takes precedence over the help message printed by the kernel. *)
let () = Self.Help.add_set_hook (fun _ b -> if b then print_main_help ())
