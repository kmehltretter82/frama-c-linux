open Sarif

let frama_c_sarif =
  let name = "frama-c" in
  let version = Config.version_and_codename in
  let semanticVersion = Config.version in
  let fullName = name ^ "-" ^ version in
  let downloadUri = "https://frama-c.com/download.html" in
  let sarifLoggerVersion = Mdr_params.version in
  Tool.create
    ~name ~version ~semanticVersion
    ~fullName ~downloadUri ~sarifLoggerVersion ()

let get_remarks () =
  let f = Mdr_params.Remarks.get () in
  if f <> "" then Parse_remarks.get_remarks f
  else Datatype.String.Map.empty

let gen_run () =
  let tool = frama_c_sarif in
  let invocations = [] in
  Run.create ~tool ~invocations ()

let generate () =
  let runs = [ gen_run () ] in
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
