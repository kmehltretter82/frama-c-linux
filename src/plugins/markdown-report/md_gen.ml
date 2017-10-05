open Cil_types
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

let insert_marks = [ Comment "BEGIN_REMARK"; Comment "END_REMARK" ]

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

let section_domains is_draft =
  if is_draft then
    Comment
      "You can give more information about the choice of EVA domains"
    :: insert_marks
  else begin
    let l = get_eva_domains () in
    [ Block
        (match l with
         | [] ->
           [Text
              (plain
                 "Only the base domain (`Cvalue`) \
                  has been used for the analysis")]
         | _ ->
           [Text
              (plain
                 "In addition to the base domain (`Cvalue`), additional \
                  domains have been used by EVA");
            DL l]
        )]
  end

let section_stubs is_draft =
  let stubbed_kf =
    List.concat
      (List.map
         (fun filename ->
            Globals.FileIndex.get_functions ~declarations:false ~filename)
         (Mdr_params.Stubs.get ())
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
         let content =
           if is_draft then insert_marks
             else
               [ Block
                   [ Text
                       [Inline_code s; Plain "has the following specification"];
                     codelines
                       "acsl" Printer.pp_funspec (Annotations.funspec kf)]]
         in
         H4 ([Inline_code s], Some s) :: content)
      l
  in
  let describe_func kf =
    let name = Kernel_function.get_name kf in
    let loc = Kernel_function.get_location kf in
    let content =
      if is_draft then insert_marks
      else
        [ Block
            [ Text
                (Inline_code name ::
                 plain_format
                   "@[<h>is defined at %a@]" Cil_datatype.Location.pretty loc);
              codelines "c"
                Printer.pp_global
                (GFun (Kernel_function.get_definition kf,loc))
            ]
        ]
    in
    H4 ([Inline_code name], Some name) :: content
  in
  let content =
    if stubbed_kf <> [] then begin
      List.map describe_func stubbed_kf
    end else []
  in
  let content = content @ use_spec in
  let content = List.concat content in
  if content = [] then
    if is_draft then
      Comment "No stubs have been used" :: insert_marks
    else
      [ Block [Text (plain "No stubs have been used for this analysis")]]
  else
    content

let gen_context is_draft =
  let context =
    if is_draft then
      Comment "You can add here some overall introduction to the analysis"
      :: insert_marks
    else []
  in
  context @ [
    H1 (plain "Context of the analysis", Some "context");
    H2 (plain "Input files", Some "c-input")
  ] @
  (if is_draft then
     Comment
       "You can add here some remarks about the set of files \
        that is considered by Frama-C"
     :: insert_marks
   else [])
  @ [
    Block [
      Text
        (plain "The C source files (not including the headers `.h` files)" @
         plain "that have been considered during the analysis \
                are the following:"
        );
      UL (List.map (fun x -> [Text [ Inline_code x ]]) (Kernel.Files.get ()));
    ];
    H2 (plain "Configuration", Some "options");
    Block [
      Text
        (plain "The options that have been used for this analysis \
                are the following.")]
  ] @
  (if is_draft then
     Comment
       "You can add here some remarks about the options used for the analysis"
     :: insert_marks
   else [])
  @
  H3 (plain "EVA Domains", Some "domains")
  :: section_domains is_draft
  @ H3 (plain "Stubbed Functions", Some "stubs")
    :: section_stubs is_draft

let string_of_pos pos =
  Format.asprintf
    "%s:%d" (Filename.basename pos.Lexing.pos_fname) pos.Lexing.pos_lnum

let string_of_pos_opt =
  function
  | None -> "Global"
  | Some pos -> string_of_pos pos

let string_of_loc (l1, _) = string_of_pos l1

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
  let treat_event { evt_kind; evt_plugin; evt_source; evt_message } =
    let evt_message =
      Str.global_replace (Str.regexp_string "\n") " " evt_message
    in
    let line =
      [ plain (string_of_pos_opt evt_source);
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

let section_event is_err nb event =
  let open Log in
  let title =
    Format.asprintf "@[<h>%s %d (%s)@]"
      (if is_err then "Error" else "Warning")
      nb
      (string_of_pos_opt event.evt_source)
  in
  let lab =
    Some
      (Format.asprintf "@[<h>%s-%d@]" (if is_err then "err" else "warn") nb)
  in
  [ H2 (plain title, lab);
    Block [ Text (plain "message text is"); Text (plain event.evt_message) ]]
  @ insert_marks

let make_events_list is_err l =
  List.concat (List.mapi (section_event is_err) l)

let make_errors_list = make_events_list true

let make_warnings_list = make_events_list false

let gen_section_warnings is_draft =
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
      let content =
        if is_draft then
          Comment "you can comment on each individual error" ::
          make_errors_list errs
        else
          [
            Block [
              Text [Bold "Important warning:";
                    Plain "Frama-C did not complete its execution ";
                    Plain "successfully. Analysis results may be inaccurate.";
                    Plain ((plural errs "The error") ^ " listed below must be");
                    Plain "fixed first before examining other ";
                    Plain "warnings and alarms."
                   ];
            ];
            make_errors_table errs
          ]
      in
      H1 (plain "Errors in the analyzer", Some "errors") :: content
    end else []
  in
  if Messages.nb_warnings () <> 0 then begin
    let content =
      if is_draft then
        Comment "you can comment on each individual error" ::
        make_warnings_list warnings
      else
        [
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
    in
    error_section @
    H1 (plain "Warnings", Some "warnings") :: content
  end else error_section

let gen_section_alarms is_draft =
  let treat_alarm e kf s ~rank:_ alarm annot (i, sec, content) =
    let kind = plain (Alarms.get_name alarm) in
    let label = "Alarm-" ^ string_of_int i in
    let link = [Link (plain_format "%d" i, "#"^label)] in
    let func = plain (Kernel_function.get_name kf) in
    let loc = string_of_loc (Cil_datatype.Stmt.loc s) in
    let loc_text = plain loc in
    let emitter = plain (Emitter.get_name e) in
    let descr = codelines "acsl" Printer.pp_code_annotation annot in
    let sec_title = plain_format "Alarm %d at %s" i loc in
    let sec_content =
      if is_draft then
        Block [ descr ] :: insert_marks
      else
        [
          Block
            [
              Text
                (plain
                   "The following ACSL assertion must hold to avoid \
                    and undefined behavior ("
                 @ kind @ plain ")");
              descr
            ]
        ]
    in
    (i+1,
     sec @ H2 (sec_title, Some label) :: sec_content,
    [ link; kind; emitter; func; loc_text ] :: content)
  in
  let _,sections, content = Alarms.fold treat_alarm (0,[],[]) in
  match content with
  | [] ->
    let text_content =
      if is_draft then
        Comment "No alarm!" :: insert_marks
      else
        [
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
    in
    H1 (plain "Results of the analysis", Some "alarms") :: text_content
  | _ :: l ->
    let alarm = if l = [] then "alarm" else "alarms" in
    let caption =
      Some (plain (String.capitalize_ascii alarm ^ " emitted by the analysis"))
    in
    let header =
      [ plain "No", Center;
        plain "Kind", Center;
        plain "Emitter", Center;
        plain "Function", Left;
        plain "Location", Left;
      ]
    in
    let text_content =
      if is_draft then begin
        sections
      end else
        [
          Block [
            Text
              [ Plain ("The table below lists the " ^ alarm);
                Plain "that have been emitted during the analysis.";
                Plain "Any execution starting from";
                Inline_code (Kernel.MainFunction.get_function_name());
                Plain "in a context matching the one used for the analysis";
                Plain "will be immune from any other undefined behavior.";
                Plain "More information on each individual alarm is";
                Plain "given in the remainder of this section"
              ]
          ];
          Table { content; caption; header }
        ]
    in
    H1 (plain "Results of the analysis", Some "alarms") :: text_content

let gen_section_callgraph is_draft =
  let content =
    if is_draft then
      Comment
        "flamegraph allow to visualize the functions and callstacks \
         whose analysis is the most costly."
      :: insert_marks
    else
      [
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
  in
  H1 (plain "Flamegraph", Some "flamegraph") :: content

let gen_section_postlude is_draft =
  if is_draft then
    [ H1 (plain "Postlude", Some "postlude");
      Comment "You can put here some concluding remarks" ]
    @ insert_marks
  else []

let gen_alarms is_draft =
  gen_section_warnings is_draft @
  gen_section_alarms is_draft @
  gen_section_callgraph is_draft @
  gen_section_postlude is_draft

let mk_date () =
  let tm = Unix.gmtime (Unix.time()) in
  plain
    (Printf.sprintf "%d-%02d-%02d"
       (1900 + tm.Unix.tm_year) (1 + tm.Unix.tm_mon) tm.Unix.tm_mday)

let mk_remarks () =
  let f = Mdr_params.Remarks.get () in
  if f <> "" then failwith "writeme"
  else Datatype.String.Map.empty

let gen_report is_draft =
  let _remarks = mk_remarks () in
  let context = gen_context is_draft in
  let alarms = gen_alarms is_draft in
  let title =
    if is_draft then plain "Frama-C Analysis Report" else plain "Draft report"
  in
  let authors = List.map (fun x -> plain x) (Mdr_params.Authors.get ()) in
  let date = mk_date () in
  let elements = context @ alarms in
  let elements =
    if is_draft then
      Comment
        "This file contains additional remarks that will be added to \
         automatically generated content by Frama-C's Markdown-report plugin. \
         For any section of the document, you can write pandoc markdown \
         content between the BEGIN and END comments. In addition, the plug-in \
         will consider any \\<!-- INCLUDE file.md --\\> comment (without backslashes) \
         as a directive to include the content of file.md in the corresponding \
         section. \
         Please don't alter the structure \
         of the document as it is used by the plugin to associate content to \
         the relevant section."
      :: elements
    else elements
  in
  let doc = { title; authors; date; elements;} in
  try
    let out = open_out (Mdr_params.Output.get()) in
    let fmt = Format.formatter_of_out_channel out in
    Markdown.pp_pandoc fmt doc;
    close_out out
  with Sys_error s ->
    Mdr_params.warning
      "Unable to open %s for writing (%s). No report will be generated"
      (Mdr_params.Output.get()) s

let main () =
  if Mdr_params.Gen_draft.get () then begin
    if Mdr_params.Generate.get () then
      Mdr_params.warning
        "-mdr-gen and -mdr-gen-draft can be activated at the \
         same time. Only draft will be generated";
    gen_report true
  end
  else if Mdr_params.Generate.get () then gen_report false

let () = Db.Main.extend main
