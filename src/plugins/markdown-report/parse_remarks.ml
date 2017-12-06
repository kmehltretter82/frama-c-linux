type env =
  { mutable current_section: string;
    mutable is_markdown: bool;
    mutable current_markdown: string list;
    (* markdown lines of current element, in reverse order. *)
    mutable remarks: Markdown.element list Datatype.String.Map.t }

let dkey = Mdr_params.register_category "remarks"

let empty_env () =
  { current_section = "";
    is_markdown = false;
    current_markdown = [];
    remarks = Datatype.String.Map.empty }

let add_channel env chan =
  try
    while true do
      let s = input_line chan in
      env.current_markdown <- s :: env.current_markdown;
    done;
  with End_of_file -> ()

let end_markdown = Str.regexp_string "<!-- BEGIN_REMARK -->"

let beg_markdown = Str.regexp_string "<!-- END_REMARK -->"

let include_markdown = Str.regexp "<!-- INCLUDE \\(.*\\) -->"

let is_section = Str.regexp "^#[^{]{\\([^}]*\\)}"

let parse_line env line =
  if env.is_markdown then begin
    if Str.string_match end_markdown line 0 then begin
      let remark = Markdown.Raw (List.rev env.current_markdown) in
      Mdr_params.debug ~dkey
        "Remark for section %s:@\n%a"
        env.current_section Markdown.pp_element remark;
      env.remarks <-
        Datatype.String.Map.add env.current_section [remark] env.remarks;
      env.current_markdown <- []
    end else if Str.string_match include_markdown line 0 then begin
      let f = Str.matched_group 1 line in
      Mdr_params.debug ~dkey
        "Remark for section %s in file %s" env.current_section f;
      try
        let chan = open_in f in
        add_channel env chan;
        close_in chan
      with Sys_error err ->
        Mdr_params.error
          "Unable to open included remarks file %s (%s), Ignoring." f err
    end else begin
      env.current_markdown <- line :: env.current_markdown;
    end
  end else if Str.string_match beg_markdown line 0 then begin
    Mdr_params.debug ~dkey
      "Checking remarks for section %s" env.current_section;
    env.is_markdown <- true
  end else if Str.string_match is_section line 0 then begin
    let sec = Str.matched_group 1 line in
    Mdr_params.debug ~dkey "Entering section %s" env.current_section;
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
  Mdr_params.debug ~dkey "Using remarks file %s" f;
  try
    let chan = open_in f in
    let { remarks } = parse_remarks (empty_env ()) chan in
    remarks
  with Sys_error err ->
    Mdr_params.error
      "Unable to open remarks file %s (%s). \
       No additional remarks will be included in the report." f err;
    Datatype.String.Map.empty
