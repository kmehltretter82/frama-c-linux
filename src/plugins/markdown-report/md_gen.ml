module Self =
  Plugin.Register(
  struct
    let name = "Markdown report"
    let shortname = "mdr"
    let help = "generates a report in markdown format"
  end)

module Output = Self.String(
struct
  let option_name = "-mdr-out"
  let arg_name = "f"
  let default = "report.md"
  let help = "sets the name of the output file to <f>"
end)

module Generate = Self.False(
struct
  let option_name = "-mdr-gen"
  let help = "generates an analysis report on the current project"
end)

module Authors = Self.String_list(
struct
  let option_name = "-mdr-authors"
  let arg_name = "l"
  let help = "list of authors of the report"
end)

module Stubs = Self.String_list(
  struct
    let option_name = "-mdr-stubs"
    let arg_name = "f1,...,fn"
    let help = "list of C files containing stub functions"
  end)

open Markdown

let all_eva_domains =
  [ "-eva-apron-box", "box domain of the Apron library";
    "-eva-apron-oct", "octagon domain of the Apron library";
    "-eva-bitwise-domain", "domain for bitwise computations";
    "-eva-equality-domain",
    "domain for storing equalities between memory locations";
    "-eva-gauges-domain",
    "gauges domain for relations between memory locations and loop counter";
    "-eva-inout-domain",
    "domain for input and output memory locations";
    "-eva-polka-equalities",
    "linear equalities domain of the Apron library";
    "-eva-polka-loose",
    "loose polyhedra domain of the Apron library";
    "-eva-polka-strict",
    "strict polyhedra domain of the Apron library";
    "-eva-sign-domain", "sign domain (useful only for demos)";
    "-eva-symbolic-locations-domain",
    "domain computing ranges of variation for symbolic locations \
     (e.g. `a[i]` when `i` is not precisely known by `Cvalue`)"
]

let plural l s =
  match l with
  | [] | [ _ ] -> s
  | _::_::_ -> s ^ "s"

let get_eva_domains () =
  Extlib.filter_map
    (fun (x,_) -> Dynamic.Parameter.Bool.get x ())
    (fun (x,y) -> ([Plain "option"; Inline_code x], plain y))
    all_eva_domains

let codelines lang pp code =
  let s = Format.asprintf "@[%a@]" pp code in
  let lines = String.split_on_char '\n' s in
  Code_block (lang, lines)

let section_domains () =
  let l = get_eva_domains () in
  Block
    (match l with
     | [] ->
       [Text
          (plain
             "Only the base domain (`Cvalue`) has been used for the analysis")]
     | _ ->
       [Text
          (plain
             "In addition to the base domain (`Cvalue`), additional domains \
              have been used by EVA");
        DL l]
    )

let section_stubs () =
  let stubbed_kf =
    List.concat
      (List.map
         (fun filename ->
            Globals.FileIndex.get_functions ~declarations:false ~filename)
         (Stubs.get ())
      )
  in
  let opt = Dynamic.Parameter.String.get "-val-use-spec" () in
  (* NB: requires OCaml >= 4.04 *)
  let l = String.split_on_char ',' opt in
  let use_spec =
    Extlib.filter_map
      (* The option can include categories in Frama-C's List/Set/Map sense,
         which begins with a '@'. In particular, @default is included by
         default. Theoretically, there could also be some '-' to suppress
         the inclusion of a function
      *)
      (fun s -> String.length s <> 0 && s.[0] <> '@' && s.[0] <> '-')
      (fun s ->
         let kf = Globals.Functions.find_by_name s in
         [ Text [Inline_code s; Plain "with the following specification"];
           codelines "acsl" Printer.pp_funspec (Annotations.funspec kf)])
      l
  in
  let describe_func kf =
    [Text
       [ Inline_code (Kernel_function.get_name kf);
         Plain
           (Format.asprintf
              "@[<h>(defined at %a)@]"
              Cil_datatype.Location.pretty
              (Kernel_function.get_location kf))
       ]]
  in
  let content =
    if stubbed_kf <> [] then begin
      [ Text
        (plain
           "The following functions have been stubbed with a C definition");
        UL (List.map describe_func stubbed_kf)]
    end else []
  in
  let content =
    if use_spec <> [] then begin
      [ Text
        (plain
          "The following functions have been stubbed with an \
           ACSL specification");
        UL use_spec]
    end else content
  in
  if content = [] then
    Block [Text (plain "No stubs have been used for this analysis")]
  else
    Block content

let gen_context () = [
  H1 (plain "Context of the analysis", Some "context");
  H2 (plain "Input files", Some "c-input");
  Block [
    Text
      (plain "The C source files (not including the headers `.h` files)" @
       plain "that have been considered during the analysis are the following:"
      );
    UL (List.map (fun x -> [Text [ Inline_code x ]]) (Kernel.Files.get ()));
  ];
  H2 (plain "Configuration", Some "options");
  Block [
    Text
      (plain "The options that have been used for this analysis \
              are the following.")];
  H3 (plain "EVA Domains", Some "domains");
  section_domains();
  H3 (plain "Stubbed Functions", Some "stubs");
  section_stubs()
]

let make_events_table print_kind caption events =
  let open Log in
  let caption = Some caption in
  let header =
    [
      plain "Location", Left;
      plain "Description", Left;
    ]
  in
  let header =
    if print_kind then (plain "Kind", Center) :: header else header
  in
  let kind = function
    | Result -> "Result"
    | Feedback -> "Feedback"
    | Debug -> "Debug"
    | Warning -> "Warning"
    | Error -> "User error"
    | Failure -> "Internal error"
  in
  let pos = function
    | None -> "Global"
    | Some pos ->
      Format.asprintf
        "%s:%d" (Filename.basename pos.Lexing.pos_fname) pos.Lexing.pos_lnum
  in
  let treat_event { evt_kind; evt_plugin; evt_source; evt_message } =
    let evt_message =
      Str.global_replace (Str.regexp_string "\n") " " evt_message
    in
    let line =
      [ plain (pos evt_source);
        [ Plain evt_message;
          Plain "(emitted by";
          Inline_code evt_plugin;
          Plain ")"
        ]
      ]
    in
    if print_kind then plain (kind evt_kind) :: line else line
  in
  let content = List.fold_left (fun l evt -> treat_event evt :: l) [] events in
  Table { caption; header; content }

let make_errors_table errs =
  make_events_table true
    (plain (plural errs "Error" ^  " reported by Frama-C")) errs

let make_warnings_table warnings =
  make_events_table
    false (plain (plural warnings "Warning" ^ " reported by Frama-C")) warnings

let gen_section_warnings () =
  let open Log in
  Messages.reset_once_flag ();
  let errs = ref [] in
  let warnings = ref [] in
  let add_event evt =
    match evt.evt_kind with
    | Error | Failure -> errs:= evt :: !errs
    | Warning -> warnings := evt :: !warnings
    | _ -> ()
  in
  Messages.iter add_event;
  let errs = !errs in
  let warnings = !warnings in
  let error_section =
    if Messages.nb_errors () <> 0 then begin
      (* Failure are supposed to stop the analyses right away, so that no
         report will be generated. On the other hand, Error messages can be
         triggered without stopping everything. Applying the same treatment
         to a Failure catched by an evil plugin cannot hurt.
      *)
      [ H1 (plain "Errors in the analyzer", Some "errors");
        Block [
          Text [Bold "Important warning:";
                Plain "Frama-C did not complete its execution successfully.";
                Plain "Analysis results may be inaccurate.";
                Plain ((plural errs "The error") ^ " listed below must be");
                Plain "fixed first before examining other warnings and alarms."
               ];
        ];
        make_errors_table errs
      ]
    end else []
  in
  if Messages.nb_warnings () <> 0 then begin
    error_section @
    [ H1 (plain "Warnings", Some "warnings");
      Block [
        Text [
          Plain ("The table below lists the " ^ plural warnings "warning");
          Plain "that have been emitted by the analyzer.";
          Plain "They might put additional assumptions on the relevance";
          Plain "of the analysis results and must be reviewed carefully";
        ];
        Text [
          Plain "Note that this does not take into account emitted alarms:";
          Plain "they are reported in";
          Link (plain "in the next section", "#alarms")
        ]
      ];
      make_warnings_table warnings
    ]
  end else error_section

let gen_section_alarms () =
  let treat_alarm e kf s ~rank:_ alarm annot l =
    let kind = plain (Alarms.get_name alarm) in
    let func = plain (Kernel_function.get_name kf) in
    let loc =
      plain
        (Format.asprintf
           "%a" Cil_datatype.Location.pretty (Cil_datatype.Stmt.loc s))
    in
    let emitter = plain (Emitter.get_name e) in
    let descr =
      [ Inline_code(Format.asprintf "%a" Printer.pp_code_annotation annot)]
    in
    [ kind; emitter; func; loc; descr ] :: l
  in
  let content = Alarms.fold treat_alarm [] in
  match content with
  | [] ->
    [ H1 (plain "Results of the analysis", Some "alarms");
      Block [
        Text
          [ Bold "No alarm"; Plain "was found during the analysis";
            Plain "Any execution starting from";
            Inline_code (Kernel.MainFunction.get_function_name ());
            Plain "in a context matching the one used for the analysis";
            Plain "will be immune from any undefined behavior."
          ]
      ]
    ]
  | _ :: l ->
    let alarm = if l = [] then "alarm" else "alarms" in
    let caption =
      Some (plain (String.capitalize_ascii alarm ^ " emitted by the analysis"))
    in
    let header =
      [ plain "Kind", Center;
        plain "Emitter", Center;
        plain "Function", Left;
        plain "Location", Left;
        plain "Description", Left;
      ]
    in
    [ H1 (plain "Results of the analysis", Some "alarms");
      Block [
        Text
          [ Plain ("The table below lists the " ^ alarm);
            Plain "that have been emitted during the analysis.";
            Plain "Any execution starting from";
            Inline_code (Kernel.MainFunction.get_function_name());
            Plain "in a context matching the one used for the analysis";
            Plain "will be immune from any other undefined behavior."
          ]
      ];
      Table { content; caption; header }
    ]

let gen_section_callgraph () =
  [ H1 (plain "Flamegraph", Some "flamegraph");
    Block [
      Text [
        Plain "The image below shows the flamegraph (";
        plain_link "http://www.brendangregg.com/flamegraphs.html";
        Plain ") for the chosen entry point."
      ]
    ];
    Block
      [ Text [Image ("flamegraph", "../server.flamegraph.svg")] ]
  ]

let gen_alarms () =
  gen_section_warnings () @
  gen_section_alarms () @
  gen_section_callgraph ()

let mk_date () =
  let tm = Unix.gmtime (Unix.time()) in
  plain
    (Printf.sprintf "%d-%02d-%02d"
       (1900 + tm.Unix.tm_year) (1 + tm.Unix.tm_mon) tm.Unix.tm_mday)

let main () =
  if Generate.get () then begin
      let context = gen_context () in
      let alarms = gen_alarms () in
      let doc =
        { title = plain "Frama-C Analysis Report";
          authors = List.map (fun x -> plain x) (Authors.get ());
          date = mk_date ();
          elements = context @ alarms
        }
      in
      try
        let out = open_out (Output.get()) in
        let fmt = Format.formatter_of_out_channel out in
        Markdown.pp_pandoc fmt doc;
        close_out out
      with Sys_error s ->
        Self.warning
          "Unable to open %s for writing (%s). No report will be generated"
          (Output.get()) s
  end

let () = Db.Main.extend main
