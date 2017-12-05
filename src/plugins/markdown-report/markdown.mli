type align = Left | Center | Right

type inline =
  | Plain of string
  | Emph of string
  | Bold of string
  | Inline_code of string
  | Link of text * string (** [Link(text,url)] *)
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

val plain: string -> text

val plain_format: ('a, Format.formatter, unit, text) format4 -> 'a

(** gives a link whose text is the URL itself. *)
val plain_link: string -> inline

val pp_inline: Format.formatter -> inline -> unit

val pp_text: Format.formatter -> text -> unit

val pp_block_element: Format.formatter -> block_element -> unit

val pp_block: Format.formatter -> block -> unit

val pp_element: Format.formatter -> element -> unit

val pp_pandoc: Format.formatter -> pandoc_markdown -> unit
