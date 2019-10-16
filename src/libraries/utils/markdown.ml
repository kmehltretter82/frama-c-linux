type align = Left | Center | Right

type href =
  | URL of string
  | Page of string
  | Name of string
  | Section of string * string

type inline =
  | Plain of string
  | Emph of string
  | Bold of string
  | Inline_code of string
  | Link of text * href (** [Link(text,url)] *)
  | Image of string * string (** [Image(alt,location)] *)

and text = inline list

type block_element =
  | Text of text (** single paragraph of text. *)
  | Block_quote of element list
  | UL of block list
  | OL of block list
  | DL of (text * text) list (** definition list *)
  | EL of (string option * text) list (** example list *)
  | Code_block of string * string list

and block = block_element list

and element =
  | Block of block
  | Raw of string list
   (** non-markdown. Each element of the list is printed as-is on its own line.
       A blank line separates the [Raw] node from the next one. *)
  | Comment of string (** markdown comment, printed <!-- like this --> *)
  | H1 of text * string option (** optional label. *)
  | H2 of text * string option
  | H3 of text * string option
  | H4 of text * string option
  | H5 of text * string option
  | H6 of text * string option
  | Table of { caption: text option; header: (text * align) list;
                content: text list list; }

type pandoc_markdown =
  { title: text;
    authors: text list;
    date: text;
    elements: element list
  }

let plain s = [ Plain s]

let plain_format txt = Format.kasprintf plain txt

let plain_link h =
  let s = match h with
    | URL url -> url
    | Page p -> p
    | Section (_,s) -> s
    | Name a -> a
  in
  Link ([Inline_code s], URL s)

let codelines lang pp code =
  let s = Format.asprintf "@[%a@]" pp code in
  let lines = String.split_on_char '\n' s in
  Code_block (lang, lines)

let id m =
  let buffer = Buffer.create (String.length m) in
  let lowercase = Char.lowercase_ascii in
  let dash = ref false in
  let emit c =
    if !dash then (Buffer.add_char buffer '-' ; dash := false) ;
    Buffer.add_char buffer c in
  String.iter
    (function
      | '0'..'9' as c -> emit c
      | 'a'..'z' as c -> emit c
      | 'A'..'Z' as c -> emit (lowercase c)
      | '.' | '_' as c -> emit c
      | ' ' | '\t' | '\n' | '-' -> dash := (Buffer.length buffer > 0)
      | _ -> ()) m ;
  Buffer.contents buffer

let pp_href fmt = function
  | URL s | Page s -> Format.pp_print_string fmt s
  | Section (p,s) -> Format.fprintf fmt "%s#%s" p (id s)
  | Name a -> Format.fprintf fmt "#%s" (id a)

let rec pp_inline fmt =
  function
  | Plain s -> Format.pp_print_string fmt s
  | Emph s -> Format.fprintf fmt "_%s_" (String.trim s)
  | Bold s -> Format.fprintf fmt "**%s**" (String.trim s)
  | Inline_code s -> Format.fprintf fmt "`%s`" (String.trim s)
  | Link (text,url) ->
    Format.fprintf fmt "@[<h>[%a](%a)@]@ " pp_text text pp_href url
  | Image (alt,url) -> Format.fprintf fmt "@[<h>![%s](%s)@]@ " alt url

and pp_text fmt l =
  match l with
  | [] -> ()
  | [ elt ] -> pp_inline fmt elt
  | elt :: text -> Format.fprintf fmt "%a@ %a" pp_inline elt pp_text text

let pp_lab fmt = function
  | None -> ()
  | Some lab -> Format.fprintf fmt " {#%s}" lab

let test_size txt = String.length (Format.asprintf "%a" pp_text txt)

let pp_dashes fmt size =
  let dashes = String.make (size + 2) '-' in
  Format.fprintf fmt "%s+" dashes

let pp_sep_line fmt sizes =
Format.fprintf fmt "@[<h>+";
List.iter (pp_dashes fmt) sizes;
Format.fprintf fmt "@]@\n"

let pp_header fmt (t,_) size =
  let real_size = test_size t in
  let spaces = String.make (size - real_size) ' ' in
  Format.fprintf fmt " %a%s |" pp_text t spaces

let pp_headers fmt l sizes =
  Format.fprintf fmt "@[<h>|";
  List.iter2 (pp_header fmt) l sizes;
  Format.fprintf fmt "@]@\n"

let compute_sizes headers contents =
  let check_line i m line =
    try max m (test_size (List.nth line i) + 2)
    with Failure _ -> m
  in
  let column_size (i,l) (h,_) =
    let max = List.fold_left (check_line i) (test_size h) contents in
    (i+1, max :: l)
  in
  let (_,sizes) = List.fold_left column_size (0,[]) headers in
  List.rev sizes

let pp_align fmt align size =
  let sep = String.make size '=' in
  match align with
  | (_,Left) -> Format.fprintf fmt ":%s=+" sep
  | (_,Center) -> Format.fprintf fmt ":%s:+" sep
  | (_,Right) -> Format.fprintf fmt "%s=:+" sep

let pp_aligns fmt headers sizes =
  Format.fprintf fmt "@[<h>+";
  List.iter2 (pp_align fmt) headers sizes;
  Format.fprintf fmt "@]@\n"

let pp_table_cell fmt size t =
  let real_size = test_size t in
  let spaces = String.make (size - real_size) ' ' in
  Format.fprintf fmt " %a%s |" pp_text t spaces

let pp_table_line fmt sizes l =
  Format.fprintf fmt "@[<h>|";
  List.iter2 (pp_table_cell fmt) sizes l;
  Format.fprintf fmt "@]@\n";
  pp_sep_line fmt sizes

let pp_table_content fmt l sizes =
  Format.fprintf fmt "@[<v>";
  List.iter (pp_table_line fmt sizes) l;
  Format.fprintf fmt "@]"

let rec pp_block_element fmt = function
  | Text t -> Format.fprintf fmt "@[<hov>%a@]@\n" pp_text t
  | Block_quote l -> pp_quote fmt l
  | UL l -> pp_list "*" fmt l
  | OL l -> pp_list "#." fmt l
  | DL l ->
    List.iter
      (fun (term,def) ->
         Format.fprintf fmt "@[<h>%a@]@\n@\n@[<hov 2>: %a@]@\n@\n"
           pp_text term pp_text def)
      l
  | EL l ->
    List.iter
      (fun (lab,txt) ->
         match lab with
         | None -> Format.fprintf fmt "@[<hov 4>(@@) %a@]@\n" pp_text txt
         | Some s -> Format.fprintf fmt "@[<hov 4>(@@%s) %a@]@\n" s pp_text txt)
      l
  | Code_block (language, lines) ->
    Format.fprintf fmt "@[<h>```%s@]@\n" language;
    List.iter (fun line -> Format.fprintf fmt "@[<h>%s@]@\n" line) lines;
    Format.fprintf fmt "```@\n"

and pp_list prefix fmt l =
  List.iter
    (fun item ->
       Format.fprintf fmt "@[<v 4>@[<hov>%s %a@]@]" prefix pp_block item)
    l

and pp_block fmt l =
  match l with
  | [ elt ] -> pp_block_element fmt elt
  | _ ->
    Format.fprintf fmt "%a@\n"
      (Format.pp_print_list ~pp_sep:Format.pp_force_newline pp_block_element) l

and pp_quote fmt l =
  List.iter
    (fun elt -> Format.fprintf fmt "@[<v>> %a@]" pp_element elt) l

and pp_element fmt = function
  | Block b -> Format.fprintf fmt "@[<v>%a@]" pp_block b
  | Raw l ->
    Format.(
      fprintf fmt "%a"
        (pp_print_list ~pp_sep:pp_force_newline pp_print_string) l)
  | Comment s ->
    Format.fprintf fmt
      "@[<hv>@[<hov 5><!-- %a@]@ -->@]" Format.pp_print_text s
  | H1(t,lab) -> Format.fprintf fmt "@[<h># %a%a@]" pp_text t pp_lab lab
  | H2(t,lab) -> Format.fprintf fmt "@[<h>## %a%a@]" pp_text t pp_lab lab
  | H3(t,lab) -> Format.fprintf fmt "@[<h>### %a%a@]" pp_text t pp_lab lab
  | H4(t,lab) -> Format.fprintf fmt "@[<h>#### %a%a@]" pp_text t pp_lab lab
  | H5(t,lab) -> Format.fprintf fmt "@[<h>##### %a%a@]" pp_text t pp_lab lab
  | H6(t,lab) -> Format.fprintf fmt "@[<h>###### %a%a@]" pp_text t pp_lab lab
  | Table { caption; header; content } ->
    (match caption with
     | None -> ()
     | Some t -> Format.fprintf fmt "@[<h>Table: %a@]@\n@\n" pp_text t);
    let sizes = compute_sizes header content in
    pp_sep_line fmt sizes;
    pp_headers fmt header sizes;
    pp_aligns fmt header sizes;
    pp_table_content fmt content sizes

let pp_elements fmt l =
  let pp_sep fmt () =
    Format.pp_print_newline fmt ();
    Format.pp_print_newline fmt ()
  in
  Format.pp_print_list ~pp_sep pp_element fmt l

let pp_authors fmt l =
  List.iter (fun t -> Format.fprintf fmt "@[<h>- %a@]@\n" pp_text t) l

let pp_pandoc fmt { title; authors; date; elements } =
  Format.fprintf fmt "@[<v>";
  if title <> [] || authors <> [] || date <> [] then begin
    Format.fprintf fmt "@[<h>---@]@\n";
    Format.fprintf fmt "@[<h>title: %a@]@\n" pp_text title;
    Format.fprintf fmt "@[<h>author:@]@\n%a" pp_authors authors;
    Format.fprintf fmt "@[<h>date: %a@]@\n" pp_text date;
    Format.fprintf fmt "@[<h>...@]@\n";
    Format.pp_print_newline fmt ();
  end;
  pp_elements fmt elements;
  Format.fprintf fmt "@]%!"
