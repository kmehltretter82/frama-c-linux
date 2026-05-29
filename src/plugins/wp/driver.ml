(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Driver for External Files                                          --- *)
(* -------------------------------------------------------------------------- *)

open Qed.Logic
open Lexing
open LogicBuiltins
open Drvlexer

let pretty fmt = function
  | EOF -> Format.pp_print_string fmt "<eof>"
  | KEY a | ID a -> Format.fprintf fmt "'%s'" a
  | LINK s -> Format.fprintf fmt "\"%s\"" s
  | BOOLEAN | INTEGER | REAL | INT _ | FLT _  | KIND _ ->
    Format.pp_print_string fmt "<type>"
  | FIELD(group,name) -> Format.fprintf fmt "%s.%s" group name

type input = {
  lexbuf : Lexing.lexbuf ;
  mutable position : Lexing.position ;
  mutable current : token ;
}

let skip input =
  if input.current <> EOF then
    begin
      input.position <- input.lexbuf.lex_curr_p ;
      input.current <- tok input.lexbuf ;
    end

let token input = input.current

let source input = input.position

let value input =
  if input.current = EOF then failwith "Value expected"
  else
    let v = value input.lexbuf in
    skip input; v

let key input a = match token input with
  | KEY b when a=b -> skip input ; true
  | _ -> false

let skipkey input a = match token input with
  | KEY b when a=b -> skip input
  | _ -> failwith (Printf.sprintf "Missing '%s'" a)

let noskipkey input a = match token input with
  | KEY b when a=b -> ()
  | _ -> failwith (Printf.sprintf "Missing '%s'" a)


let ident input = match token input with
  | ID x | LINK x -> skip input ; x
  | _ -> failwith "missing identifier"

let kind input =
  let kd = match token input with
    | INTEGER -> Z
    | REAL -> R
    | BOOLEAN -> A
    | INT i -> I (Ctypes.c_int i)
    | FLT f -> F (Ctypes.c_float f)
    | KIND x -> x
    | ID _ -> A
    | _ -> failwith "<type> expected"
  in skip input ; kd

let parameter input =
  let k = kind input in
  match token input with
  | ID _ -> skip input ; k
  | _ -> k

let rec parameters input =
  if key input ")" then [] else
    let p = parameter input in
    if key input "," then p :: parameters input else
    if key input ")" then [p] else
      failwith "Missing ',' or ')'"

let signature input =
  if key input "(" then parameters input else []

let rec depend input =
  match token input with
  | ID a | LINK a ->
    skip input ;
    ignore (key input ",") ;
    a :: depend input
  | _ -> []

let rec conv_bal default (name,bal) =
  match bal with
  | `Default -> conv_bal default (name,default)
  | `Left  -> Qed.Engine.F_left name
  | `Right -> Qed.Engine.F_right name
  | `Nary  -> Qed.Engine.F_call name

let link def input =
  match token input with
  | LINK f | ID f ->
    let link = conv_bal def (f,(bal input.lexbuf)) in
    skip input; link
  | _ -> failwith "Missing link symbol"

let linkstring input =
  match recorstring input.lexbuf with
  | `String f ->
    skip input ; f
  | `RecString l ->
    skip input ;
    begin try List.assoc "why3" l
      with Not_found ->
        failwith "a link must contain an entry for 'why3'"
    end
  | _ -> failwith "Missing link symbol"

let input_string input =
  match token input with
  | LINK f | ID f ->
    skip input ; f
  | _ -> failwith "String or ident expected"


let op = {
  invertible = false ;
  associative = false ;
  commutative = false ;
  idempotent = false ;
  neutral = E_none ;
  absorbent = E_none ;
}

let op_elt input =
  ignore (key input ":") ;
  let op = input_string input in
  skipkey input ":" ;
  match op with
  | "0" -> E_int 0
  | "1" -> E_int 1
  | "-1" -> E_int (-1)
  | "\\true" -> E_true
  | "\\false" -> E_false
  | _ ->
    match LogicBuiltins.constant op with
    | ACSLDEF -> failwith (Printf.sprintf "Symbol '%s' not found" op)
    | HACK _ -> failwith (Printf.sprintf "Symbol '%s' hacked" op)
    | LFUN lfun -> E_fun(lfun,[])

let rec op_link op input =
  match token input with
  | LINK _ ->
    Operator op, link `Left input
  | ID "associative" -> skip input ; skipkey input ":" ;
    op_link { op with associative = true } input
  | ID "commutative" -> skip input ; skipkey input ":" ;
    op_link { op with commutative = true } input
  | ID "ac" -> skip input ; skipkey input ":" ;
    op_link { op with commutative = true ; associative = true } input
  | ID "idempotent" -> skip input ; skipkey input ":" ;
    op_link { op with idempotent = true } input
  | ID "invertible" -> skip input ; skipkey input ":" ;
    op_link { op with invertible = true } input
  | ID "neutral" ->
    skip input ; let e = op_elt input in
    op_link { op with neutral = e } input
  | ID "absorbent" ->
    skip input ; let e = op_elt input in
    op_link { op with absorbent = e } input
  | ID t -> failwith (Printf.sprintf "Unknown tag '%s'" t)
  | _ -> failwith "Missing <tag> or <link>"

let logic_link input =
  match token input with
  | LINK _ ->
    Function, link `Nary input
  | ID "constructor" ->
    skip input ; skipkey input ":" ;
    Qed.Logic.Constructor, link `Nary input
  | ID "injective" ->
    skip input ; skipkey input ":" ;
    Injection, link `Nary input
  | _ -> op_link op input

let rec parse ~driver_dir library input =
  match token input with
  | EOF -> ()
  | KEY "library" ->
    skip input ;
    let name = input_string input in
    ignore (key input ":") ;
    let depends = depend input in
    ignore (key input ";") ;
    add_library name depends ;
    parse ~driver_dir name input
  | KEY "type" ->
    skip input ;
    let name = ident input in
    let source = source input in
    noskipkey input "=" ;
    let link = linkstring input in
    add_type ~source:(Filepos.of_lexing_pos source) name ~library ~link () ;
    skipkey input ";" ;
    parse ~driver_dir library input
  | KEY "ctor" ->
    skip input ;
    let name = ident input in
    let source = source input in
    let args = signature input in
    skipkey input "=" ;
    let link = link `Nary input in
    add_ctor ~source:(Filepos.of_lexing_pos source) name args ~library ~link () ;
    skipkey input ";" ;
    parse ~driver_dir library input
  | KEY "logic" ->
    skip input ;
    let result = kind input in
    let name = ident input in
    let source = source input in
    let args = signature input in
    if key input ":=" then
      begin
        let alias = ident input in
        add_alias ~source:(Filepos.of_lexing_pos source) name args ~alias () ;
      end
    else
      begin
        skipkey input "=" ;
        let category,link = logic_link input in
        add_logic ~source:(Filepos.of_lexing_pos source) result name args ~library ~category ~link () ;
      end ;
    skipkey input ";" ;
    parse ~driver_dir library input
  | KEY "predicate" ->
    skip input ;
    let name = ident input in
    let source = source input in
    let args = signature input in
    if key input ":=" then
      begin
        let alias = ident input in
        add_alias ~source:(Filepos.of_lexing_pos source) name args ~alias () ;
      end
    else
      begin
        noskipkey input "=" ;
        let link = linkstring input in
        add_predicate ~source:(Filepos.of_lexing_pos source) name args ~library ~link () ;
      end ;
    skipkey input ";" ;
    parse ~driver_dir library input
  | FIELD (group,var) ->
    skip input ;
    begin match token input with
      | KEY ":=" ->
        let v = value input in
        set_option ~driver_dir group var ~library v
      | KEY "+=" ->
        let v = value input in
        add_option ~driver_dir group var ~library v
      | _ -> failwith "Missing ':=' or '+='"
    end;
    skipkey input ";" ;
    parse ~driver_dir library input
  | _ -> failwith "Unexpected entry"

let load_file ?(ontty=`Transient) file =
  try
    Wp_parameters.feedback ~dkey:dkey_driver ~ontty "Loading driver '%a'"
      Filepath.pretty file;
    let driver_dir = Filepath.dirname file in
    let inc = open_in (Filepath.to_string_abs file) in
    let lex = Lexing.from_channel inc in
    let position = {
      lex.Lexing.lex_curr_p with Lexing.pos_fname = Filepath.to_string_abs file
    } in
    let input = { current = tok lex ; position = position ; lexbuf = lex } in
    try
      lex.Lexing.lex_curr_p <- position ;
      parse ~driver_dir:(Filepath.to_string_abs driver_dir) "qed" input ;
      close_in inc
    with Failure msg ->
      close_in inc ;
      let source = lex.Lexing.lex_start_p in
      Wp_parameters.abort ~current:false
        ~source:(Filepos.of_lexing_pos source) "(Driver Error) %s (at %a)" msg
        pretty (token input)
  with exn ->
    Wp_parameters.abort
      ~current:false
      "Error in driver '%a': %s" Filepath.pretty file (Printexc.to_string exn)

let loaded : (Filepath.t list, driver) Hashtbl.t =Hashtbl.create 10
let load_driver () =
  let drivers = Wp_parameters.Drivers.get () in
  begin try
      Hashtbl.find loaded drivers
    with Not_found ->
      let driver_basename (file : Filepath.t) =
        let base = Filepath.basename file in
        try Filename.chop_extension base
        with Invalid_argument _ -> base in
      let drvs = List.map driver_basename drivers in
      let id = String.concat "_" drvs in
      let descr = String.concat "," drvs in
      let includes =
        let directories =
          [Wp_parameters.Share.get_dir "."]
        in
        if Wp_parameters.has_dkey dkey then
          Wp_parameters.debug ~dkey "Included directories:%t"
            (fun fmt ->
               List.iter
                 (fun d -> Format.fprintf fmt "@\n - '%a'" Filepath.pretty d)
                 directories
            );
        directories
      in
      let configure ()=
        let drivers =
          List.map (fun file ->
              if Filesystem.exists file
              then file
              else LogicBuiltins.find_lib file)
            drivers in
        let default = Wp_parameters.Share.get_file "wp.driver" in
        let membytes =
          Wp_parameters.Share.get_file @@
          if Machine.little_endian ()
          then "membytes_le.driver"
          else "membytes_be.driver"
        in
        let feedback = Wp_parameters.Share.is_set () in
        let ontty = if feedback then `Message else `Transient in
        load_file ~ontty default;
        load_file ~ontty membytes;
        List.iter load_file drivers
      in
      let driver = LogicBuiltins.new_driver ~id ~descr ~includes ~configure () in
      Hashtbl.add loaded drivers driver;
      if Wp_parameters.has_dkey dkey_driver  then LogicBuiltins.dump () ;
      driver
  end
