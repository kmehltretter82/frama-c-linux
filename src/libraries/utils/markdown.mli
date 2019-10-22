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
  | Link of text * href
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

type elements = element list

type pandoc_markdown =
  { title: text;
    authors: text list;
    date: text;
    elements: elements
  }

(** creates a document from a list of elements and optional metadatas.
    Defaults are:
    - title: empty
    - authors: empty list
    - date: current day, in ISO format
*)
val pandoc:
  ?title:text -> ?authors: text list -> ?date: text -> elements ->
  pandoc_markdown

(** get the content of a file as raw markdown.
    @raise Sys_error if there's no such file.
*)
val raw_markdown: string -> element

val plain: string -> text

val plain_format: ('a, Format.formatter, unit, text) format4 -> 'a

(** glue text fragments. *)
val glue: ?sep: text -> text list -> text

(** transforms a string into an anchor name, roughly following
    pandoc's conventions.
*)
val id: string -> string

(** adds a [H1] header with the given [title] on top of the given elements.
    If name is not explicitly provided,
    the header will have as associated anchor [id title]
*)
val section: ?name:string -> title:string -> elements -> elements

(** [subsections header body] returns a list of [element]s where the [body]'s
    headers have been increased by one (i.e. [H1] becomes [H2]).
    [H5] stays at [H5], though.
*)
val subsections: elements -> elements list -> elements

(** returns an internal link relative to the current page *)
val link_current_page: string -> href

(** gives a link whose text is the URL itself. *)
val plain_link: href -> inline

(** [codelines lang pp code] returns a [Code_block] for [code], written
    in [lang], as pretty-printed by [pp]. *)
val codelines:
  string -> (Format.formatter -> 'a -> unit) -> 'a -> block_element

val pp_inline: Format.formatter -> inline -> unit

val pp_text: Format.formatter -> text -> unit

val pp_block_element: Format.formatter -> block_element -> unit

val pp_block: Format.formatter -> block -> unit

val pp_element: Format.formatter -> element -> unit

val pp_elements: Format.formatter -> elements -> unit

val pp_pandoc: Format.formatter -> pandoc_markdown -> unit
