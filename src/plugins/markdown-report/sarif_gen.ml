open Sarif

let frama_c_sarif =
  let name = "frama-c" in
  let version = Config.version_and_codename in
  let semanticVersion = Config.version in
  let fullName = name ^ "-" ^ version in
  let downloadUri = "https://frama-c.com/download.html" in
  let sarifLoggerVersion = Mdr_version.version in
  Tool.create
    ~name ~version ~semanticVersion
    ~fullName ~downloadUri ~sarifLoggerVersion ()


let get_remarks () =
  let f = Mdr_params.Remarks.get () in
  if f <> "" then Parse_remarks.get_remarks f
  else Datatype.String.Map.empty

let get_remark remarks label =
  match Datatype.String.Map.find_opt label remarks with
  | None -> []
  | Some l -> l

let gen_invocation () =
  let commandLine = Array.fold_right (fun s acc -> s ^ " " ^ acc) Sys.argv "" in
  let arguments = List.tl (Array.to_list Sys.argv) in
  Invocation.create ~commandLine ~arguments ()

let make_message alarm annot remark =
  let open Markdown in
  let kind = plain (Alarms.get_name alarm ^ ":") in
  let descr = codelines "acsl" Printer.pp_code_annotation annot in
  let summary = Block [Text kind; descr] in
  let markdown = summary :: remark in
  Message.markdown ~markdown ()

let gen_results remarks =
  let treat_alarm _e _kf s ~rank:_ alarm annot (i, content) =
    let label = "Alarm-" ^ string_of_int i in
    let level = Result_level.warning in
    let remark = get_remark remarks label in
    let message = make_message alarm annot remark in
    let locations = [ Location.of_loc (Cil_datatype.Stmt.loc s) ] in
    let res =
      Sarif_result.create ~level ~message ~locations ()
    in
    (i+1, res :: content)
  in
  let _, content = Alarms.fold treat_alarm (0, []) in
  List.rev content

let is_alarm = function
  | Property.IPCodeAnnot (_,_,ca) -> Extlib.has_some (Alarms.find ca)
  | _ -> false

let level_of_status =
  let open Property_status.Feedback in
  let open Sarif.Result_level in
  function
  | Never_tried -> notApplicable
  | Considered_valid | Valid | Valid_under_hyp | Valid_but_dead -> pass
  | Unknown | Unknown_but_dead -> warning
  | Invalid | Invalid_under_hyp | Invalid_but_dead -> error
  | Inconsistent -> note

let make_ip_message ip =
  let text = Format.asprintf "@[%a@]" Property.short_pretty ip in
  Message.plain_text ~text ()

let gen_status ip =
  let status = Property_status.Feedback.get ip in
  let level = level_of_status status in
  let locations = [ Location.of_loc (Property.location ip) ] in
  let message = make_ip_message ip in
  Sarif_result.create ~level ~locations ~message ()

let gen_statuses () =
  let f ip content =
    if is_alarm ip then content else (gen_status ip) :: content
  in
  List.rev (Property_status.fold f [])

let gen_files () =
  let add_src_file f =
    let key = Filename.chop_extension (Filename.basename f) in
    let fileLocation = FileLocation.create ~uri:(Filepath.normalize f) () in
    let roles = [ Role.analysisTarget ] in
    let mimeType = "text/x-csrc" in
    key, File.create ~fileLocation ~roles ~mimeType ()
  in
  List.map add_src_file (Kernel.Files.get ())

let gen_run remarks =
  let tool = frama_c_sarif in
  let invocations = [gen_invocation ()] in
  let results = gen_results remarks in
  let results = results @ (gen_statuses ()) in
  let files = gen_files () in
  Run.create ~tool ~invocations ~results ~files ()

let generate () =
  let remarks = get_remarks () in
  let runs = [ gen_run remarks ] in
  let json = Schema.create ~runs () in
  let out = Mdr_params.Output.get () in
  let chan =
    if out = "" then stdout
    else begin
      try open_out out
      with Sys_error s ->
        Mdr_params.abort "Unable to open output file %s: %s" out s
    end
  in
  Yojson.Safe.to_channel chan (Schema.to_yojson json)
