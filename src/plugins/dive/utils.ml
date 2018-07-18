(* 
let source_text loc =
  let pos_start,pos_end = loc in
  try
    let in_ch = open_in pos_start.Lexing.pos_fname in
    try
      for i = 0 to pos_start.Lexing.pos_lnum - 1 do
        ignore (input_line in_ch)
      done;
      let line = input_line in_ch in
      if pos_start.Lexing.pos_bol
      Some ()
    with _ -> close_in_noerr in_ch; None
  with _ -> None
*)


let source_text loc =
  let pos_start,pos_end = loc in
  try
    Self.result "%a - %a" Cil_types_debug.pp_lexing_position pos_start Cil_types_debug.pp_lexing_position pos_end;
    let in_ch = open_in pos_start.Lexing.pos_fname in
    try
      let pos = pos_start.Lexing.pos_cnum in
      let len = pos_end.Lexing.pos_cnum - pos_start.Lexing.pos_cnum in
      let buf = Bytes.create len in
      let count = input in_ch buf pos len in
      close_in in_ch;
      if count != len then
        None
      else
        Some (Bytes.to_string buf)
    with _ -> close_in_noerr in_ch; None
  with _ -> None
