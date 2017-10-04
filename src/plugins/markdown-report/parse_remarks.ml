type env =
  { mutable current_section: string;
    mutable is_markdown: bool;
    current_markdown: Buffer.t;
    mutable remarks: Markdown.element list Datatype.String.Map.t }

let empty_env () =
  { current_section = "";
    is_markdown = false;
    current_markdown = Buffer.create 40;
    remarks = Datatype.String.Map.empty }

let add_channel buf chan =
  try
    while true do
      let s = input_line chan in
      Buffer.add_string buf s;
      Buffer.add_char buf '\n'
    done;
  with End_of_file -> ()

let end_markdown = Str.regexp_string "<!-- BEGIN_REMARK -->"

let beg_markdown = Str.regexp_string "<!-- END_REMARK -->"

let include_markdown = Str.regexp "<!-- INCLUDE \\(.*\\) -->"

let is_section = Str.regexp "^#[^{]{\\([^}]*\\)}"

let parse_line env line =
  if env.is_markdown then begin
    if Str.string_match end_markdown line 0 then begin
      env.remarks <-
        Datatype.String.Map.add
          env.current_section
          [ Markdown.Raw (Buffer.contents env.current_markdown)]
          env.remarks
    end else if Str.string_match include_markdown line 0 then begin
      let f = Str.matched_group 1 line in
      try
        let chan = open_in f in
        add_channel env.current_markdown chan;
        close_in chan
      with Sys_error err ->
        Mdr_params.error
          "Unable to open included remarks file %s (%s), Ignoring." f err
    end else begin
      Buffer.add_string env.current_markdown line;
      Buffer.add_char env.current_markdown '\n'
    end
  end else if Str.string_match beg_markdown line 0 then begin
    env.is_markdown <- true
  end else if Str.string_match is_section line 0 then begin
    let sec = Str.matched_group 1 line in
    env.current_section <- sec
  end

let parse_remarks env chan =
  try
    while true do
      let s = input_line chan in
      parse_line env s
    done;
    assert false
  with End_of_file ->
    close_in chan;
    env

let get_remarks f =
  try
    let chan = open_in f in
    let { remarks } = parse_remarks (empty_env ()) chan in
    remarks
  with Sys_error err ->
    Mdr_params.error
      "Unable to open remarks file %s (%s). \
       No additional remarks will be included in the report." f err;
    Datatype.String.Map.empty
