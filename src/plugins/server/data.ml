(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Data Encoding                                                      --- *)
(* -------------------------------------------------------------------------- *)

module Js = Yojson.Basic
module Ju = Yojson.Basic.Util

type json = Js.t
let pretty = Js.pretty_print ~std:false

module type S =
sig
  type t
  val syntax : Syntax.t
  val of_json : json -> t
  val to_json : t -> json
end

module type Info =
sig
  val page : Doc.page
  val name : string
  val descr : Markdown.text
end

type 'a data = (module S with type t = 'a)

exception InputError of string

let failure ?json msg =
  let add_json msg =
    let msg = match json with
      | None -> msg
      | Some json ->
        Format.asprintf "@[%s:@ %s@]" msg (Js.pretty_to_string json)
    in
    raise(InputError(msg))
  in
  Pretty_utils.ksfprintf add_json msg

let failure_from_type_error msg json =
  failure ~json "%s" msg

let page = Doc.page `Kernel ~title:"Basic Types" ~filename:"data.md"

(* -------------------------------------------------------------------------- *)
(* --- Option                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Joption(A : S) : S with type t = A.t option =
struct
  type t = A.t option

  let nullable = try ignore (A.of_json `Null) ; true with _ -> false
  let syntax =
    Syntax.option (if not nullable then A.syntax else Syntax.tuple [A.syntax])

  let to_json = function
    | None -> `Null
    | Some v -> if nullable then `List [A.to_json v] else A.to_json v

  let of_json = function
    | `Null -> None
    | `List [js] when nullable -> Some (A.of_json js)
    | js -> Some (A.of_json js)

end

(* -------------------------------------------------------------------------- *)
(* --- Tuples                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Jpair(A : S)(B : S) : S with type t = A.t * B.t =
struct
  type t = A.t * B.t
  let syntax = Syntax.tuple [A.syntax;B.syntax]
  let to_json (x,y) = `List [ A.to_json x ; B.to_json y ]
  let of_json = function
    | `List [ ja ; jb ] -> A.of_json ja , B.of_json jb
    | js -> failure ~json:js "Expected list with 2 elements"
end

module Jtriple(A : S)(B : S)(C : S) : S with type t = A.t * B.t * C.t =
struct
  type t = A.t * B.t * C.t
  let syntax = Syntax.tuple [A.syntax;B.syntax;C.syntax]
  let to_json (x,y,z) = `List [ A.to_json x ; B.to_json y ; C.to_json z ]
  let of_json = function
    | `List [ ja ; jb ; jc ] -> A.of_json ja , B.of_json jb , C.of_json jc
    | js -> failure ~json:js "Expected list with 3 elements"
end

(* -------------------------------------------------------------------------- *)
(* --- Lists                                                              --- *)
(* -------------------------------------------------------------------------- *)

module Jlist(A : S) : S with type t = A.t list =
struct
  type t = A.t list
  let syntax = Syntax.array A.syntax
  let to_json xs = `List (List.map A.to_json xs)
  let of_json js = List.map A.of_json (Ju.to_list js)
end

(* -------------------------------------------------------------------------- *)
(* --- Arrays                                                             --- *)
(* -------------------------------------------------------------------------- *)

module Jarray(A : S) : S with type t = A.t array =
struct
  type t = A.t array
  let syntax = Syntax.array A.syntax
  let to_json xs = `List (List.map A.to_json (Array.to_list xs))
  let of_json js = Array.of_list @@ List.map A.of_json (Ju.to_list js)
end

(* -------------------------------------------------------------------------- *)
(* --- Collections                                                        --- *)
(* -------------------------------------------------------------------------- *)

module type S_collection =
sig
  include S
  module Joption : S with type t = t option
  module Jlist : S with type t = t list
  module Jarray : S with type t = t array
end

module Collection(A : S) : S_collection with type t = A.t =
struct
  include A
  module Joption = Joption(A)
  module Jlist = Jlist(A)
  module Jarray = Jarray(A)
end

(* -------------------------------------------------------------------------- *)
(* --- Atomic Types                                                       --- *)
(* -------------------------------------------------------------------------- *)

module Junit : S with type t = unit =
struct
  type t = unit
  let syntax = Syntax.unit
  let of_json _js = ()
  let to_json () = `Null
end

module Jany : S with type t = json =
struct
  type t = json
  let syntax = Syntax.any
  let of_json js = js
  let to_json js = js
end

module Jbool : S_collection with type t = bool =
  Collection
    (struct
      type t = bool
      let syntax = Syntax.boolean
      let of_json = Ju.to_bool
      let to_json b = `Bool b
    end)

module Jint : S_collection with type t = int =
  Collection
    (struct
      type t = int
      let syntax = Syntax.int
      let of_json = Ju.to_int
      let to_json n = `Int n
    end)

module Jfloat : S_collection with type t = float =
  Collection
    (struct
      type t = float
      let syntax = Syntax.number
      let of_json = Ju.to_number
      let to_json v = `Float v
    end)

module Jstring : S_collection with type t = string =
  Collection
    (struct
      type t = string
      let syntax = Syntax.string
      let of_json = Ju.to_string
      let to_json s = `String s
    end)

module Jident : S_collection with type t = string =
  Collection
    (struct
      type t = string
      let syntax = Syntax.ident
      let of_json = Ju.to_string
      let to_json s = `String s
    end)

let text_page = Doc.page `Kernel ~title:"Rich Text Format" ~filename:"text.md"

module Jtext =
struct
  include Jany
  let syntax = Syntax.publish ~page:text_page ~name:"text"
      ~synopsis:Syntax.any ~descr:(Markdown.plain "Formatted text.") ()
end

(* -------------------------------------------------------------------------- *)
(* --- Records                                                            --- *)
(* -------------------------------------------------------------------------- *)

module Fmap = Map.Make(String)

module Record =
struct

  type 'a record = json Fmap.t

  type ('r,'a) field = {
    member : 'r record -> bool ;
    getter : 'r record -> 'a ;
    setter : 'r record -> 'a -> 'r record ;
  }

  type 'a signature = {
    page : Doc.page ;
    name : string ;
    descr : Markdown.text ;
    mutable fields : Syntax.field list ;
    mutable default : 'a record ;
    mutable published : bool ;
  }

  module type S =
  sig
    type r
    include S with type t = r record
    val default : t
    val has : (r,'a) field -> t -> bool
    val get : (r,'a) field -> t -> 'a
    val set : (r,'a) field -> 'a -> t -> t
  end

  let signature ~page ~name ~descr () = {
    page ; name ; descr ;
    published = false ;
    fields = [] ;
    default = Fmap.empty ;
  }

  let invalid name reason =
    let msg = Printf.sprintf "Server.Data.Record.%s: %s" name reason in
    raise (Invalid_argument msg)

  let field (type a r) (s : r signature)
      ~name ~descr ?default (d : a data) : (r,a) field =
    if s.published then
      invalid s.name (Printf.sprintf "published record (%s)" name) ;
    let module D = (val d) in
    begin match default with
      | None -> ()
      | Some v -> s.default <- Fmap.add name (D.to_json v) s.default
    end ;
    let field = Syntax.{
        fd_name = name ;
        fd_syntax = D.syntax ;
        fd_descr = descr ;
      } in
    s.fields <- field :: s.fields ;
    let member r = Fmap.mem name r in
    let getter r = D.of_json (Fmap.find name r) in
    let setter r v = Fmap.add name (D.to_json v) r in
    { member ; getter ; setter }

  let option (type a r) (s : r signature)
      ~name ~descr (d : a data) : (r,a option) field =
    if s.published then
      invalid s.name (Printf.sprintf "published record (%s)" name) ;
    let module D = (val d) in
    let field = Syntax.{
        fd_name = name ;
        fd_syntax = option D.syntax ;
        fd_descr = descr ;
      } in
    s.fields <- field :: s.fields ;
    let member r = Fmap.mem name r in
    let getter r =
      try Some (D.of_json (Fmap.find name r)) with Not_found -> None in
    let setter r = function
      | None -> Fmap.remove name r
      | Some v -> Fmap.add name (D.to_json v) r in
    { member ; getter ; setter }

  let publish (type r) (s : r signature) =
    if s.published then
      invalid s.name "already published record" ;
    let module M =
    struct
      type nonrec r = r
      type t = r record
      let descr = s.descr
      let syntax =
        let fields = Syntax.fields ~title:"Field" (List.rev s.fields) in
        Syntax.publish ~page:s.page ~name:s.name ~descr
          ~synopsis:(Syntax.record [])
          ~details:[fields] ()
      let default = s.default
      let has fd r = fd.member r
      let get fd r = fd.getter r
      let set fd v r = fd.setter r v
      let of_json js =
        List.fold_left
          (fun r (fd,js) -> Fmap.add fd js r)
          default (Ju.to_assoc js)
      let to_json r : json =
        `Assoc (Fmap.fold (fun fd js fds -> (fd,js) :: fds) r [])
    end in
    begin
      s.default <- Fmap.empty ;
      s.fields <- [] ;
      s.published <- true ;
      (module M : S with type r = r)
    end

end

module Jmarkdown : S with type t = Markdown.text =
struct

  type t = Markdown.text
  let syntax = Syntax.publish ~page
      ~name:"markdown" ~descr:(Markdown.plain "Markdown (inlined text)")
      ~synopsis:Syntax.string ()
  let of_json js = Markdown.plain (Ju.to_string js)
  let to_json txt =
    `String (Rich_text.to_string ~margin:80 (Markdown.pp_text ?page:None) txt)

end

(* -------------------------------------------------------------------------- *)
(* --- Enums                                                              --- *)
(* -------------------------------------------------------------------------- *)

module Tag = Collection
    (struct
      type t = Syntax.tag

      let syntax = Syntax.publish ~page ~name:"tag"
          ~descr:(Markdown.plain "Tag description")
          ~synopsis:(Syntax.record [
              "name",Syntax.string ;
              "label",Jmarkdown.syntax ;
              "descr",Jmarkdown.syntax ;
            ]) ()

      let to_json tg = `Assoc [
          "name", `String tg.Syntax.tag_name ;
          "label", Jmarkdown.to_json tg.tag_label ;
          "descr" , Jmarkdown.to_json tg.tag_descr ;
        ]

      let of_json js = Syntax.{
          tag_name = Ju.member "name" js |> Ju.to_string ;
          tag_label = Ju.member "label" js |> Jmarkdown.of_json ;
          tag_descr = Ju.member "descr" js |> Jmarkdown.of_json ;
        }
    end)

module Enum =
struct

  type 'a dictionary = {
    page : Doc.page ;
    name : string ;
    title : string ;
    descr : Markdown.text ;
    values : (string,'a option) Hashtbl.t ;
    vindex : ('a,string) Hashtbl.t ;
    mutable syntax : Markdown.text ;
    mutable published : bool ;
    mutable tags : Syntax.tag list ;
  }

  type 'a tag = string
  type 'a prefix = string

  let tag_name tg = tg
  let tag_label a = function
    | None -> Markdown.plain (String.(capitalize_ascii (lowercase_ascii a)))
    | Some lbl -> lbl

  let dictionary ~page ~name ~title ~descr () = {
    page ; name ; descr ; title ;
    published = false ;
    values = Hashtbl.create 0 ;
    vindex = Hashtbl.create 0 ;
    syntax = [] ;
    tags = [] ;
  }

  let invalid name reason =
    let msg = Printf.sprintf "Server.Data.Enum.%s: %s" name reason in
    raise (Invalid_argument msg)

  let page (d : 'a dictionary) = d.page
  let name (d : 'a dictionary) = d.name
  let syntax (d : 'a dictionary) = d.syntax

  let tag (d : 'a dictionary) ~name ?label ~descr ?value () : 'a tag =
    if Hashtbl.mem d.values name then
      invalid d.name (Printf.sprintf "duplicate tag (%s)" name) ;
    let tg = Syntax.{
        tag_name = name ;
        tag_label = tag_label name label ;
        tag_descr = descr ;
      } in
    d.tags <- tg :: d.tags ;
    Hashtbl.add d.values name value ;
    begin match value with
      | None -> ()
      | Some v -> Hashtbl.add d.vindex v name
    end ; name

  let find_tag (d : 'a dictionary) name =
    if Hashtbl.mem d.values name then name else raise Not_found

  let instance = Printf.sprintf "%s:%s"

  let prefix (d : 'a dictionary) ~prefix ?(var="*") ?label ~descr () =
    let tg = Syntax.{
        tag_name = instance prefix var ;
        tag_label = tag_label (prefix ^ ".") label ;
        tag_descr = descr ;
      } in
    d.tags <- tg :: d.tags ; prefix

  let extends d prefix ~name ?label ~descr ?value () =
    tag d ~name:(instance prefix name) ?label ~descr ?value ()

  let to_json name vindex v =
    try `String (Hashtbl.find vindex v)
    with Not_found ->
      failure "[%s] Value not found" name

  let of_json name values js =
    let tag = Ju.to_string js in
    match Hashtbl.find values tag with
    | Some v -> v
    | None ->
      failure "[%s] No registered value for tag '%s" name tag
    | exception Not_found ->
      failure "[%s] Not registered tag '%s" name tag

  let tags d = List.rev d.tags

  let publish (type a) (d : a dictionary) ?tag () =
    if d.published then
      invalid d.name "already published" ;
    let module M =
    struct
      type t = a
      let descr = d.descr
      let syntax =
        let tags () = [Syntax.tags ~title:d.title (List.rev d.tags)] in
        Syntax.publish ~page:d.page ~name:d.name ~descr
          ~synopsis:(Syntax.string) ~generated:tags ()
      let of_json = of_json d.name d.values
      let to_json =
        match tag with
        | None -> to_json d.name d.vindex
        | Some to_tag -> fun x -> `String (to_tag x)
    end in
    begin
      d.published <- true ;
      d.syntax <- Syntax.text M.syntax ;
      (module M : S with type t = a)
    end

end

(* -------------------------------------------------------------------------- *)
(* --- Index                                                              --- *)
(* -------------------------------------------------------------------------- *)

(** Simplified [Map.S] *)
module type Map =
sig
  type 'a t
  type key
  val empty : 'a t
  val add : key -> 'a -> 'a t -> 'a t
  val find : key -> 'a t -> 'a
end

module type Index =
sig
  include S_collection
  val get : t -> int
  val find : int -> t
  val clear : unit -> unit
end

let publish_id (module A : Info) =
  Syntax.publish
    ~page:A.page ~name:A.name ~synopsis:Syntax.int ~descr:A.descr ()

module INDEXER(M : Map)(I : Info) :
sig
  type index
  val create : unit -> index
  val clear : index -> unit
  val get : index -> M.key -> int
  val find : index -> int -> M.key
  val to_json : index -> M.key -> json
  val of_json : index -> json -> M.key
end =
struct

  type index = {
    mutable kid : int ;
    mutable index : int M.t ;
    lookup : (int,M.key) Hashtbl.t ;
  }

  let create () = {
    kid = 0 ;
    index = M.empty ;
    lookup = Hashtbl.create 0 ;
  }

  let clear m =
    begin
      m.kid <- 0 ;
      m.index <- M.empty ;
      Hashtbl.clear m.lookup ;
    end

  let get m a =
    try M.find a m.index
    with Not_found ->
      let id = m.kid in
      m.kid <- succ id ;
      m.index <- M.add a id m.index ;
      Hashtbl.add m.lookup id a ; id

  let find m id = Hashtbl.find m.lookup id

  let to_json m a = `Int (get m a)
  let of_json m js =
    let id = Ju.to_int js in
    try find m id
    with Not_found ->
      failure "[%s] No registered id #%d" I.name id

end

module Static(M : Map)(I : Info) : Index with type t = M.key =
struct
  module INDEX = INDEXER(M)(I)
  let index = INDEX.create ()
  let clear () = INDEX.clear index
  let get = INDEX.get index
  let find = INDEX.find index
  include Collection
      (struct
        type t = M.key
        let syntax = publish_id (module I)
        let of_json = INDEX.of_json index
        let to_json = INDEX.to_json index
      end)
end

module Index(M : Map)(I : Info) : Index with type t = M.key =
struct

  module INDEX = INDEXER(M)(I)
  module TYPE : Datatype.S with type t = INDEX.index =
    Datatype.Make
      (struct
        type t = INDEX.index
        include Datatype.Undefined
        let reprs = [INDEX.create()]
        let name = "Server.Data.Index.Type." ^ I.name
        let mem_project = Datatype.never_any_project
      end)
  module STATE = State_builder.Ref(TYPE)
      (struct
        let name = "Server.Data.Index.State." ^ I.name
        let dependencies = []
        let default = INDEX.create
      end)

  let index () = STATE.get ()
  let clear () = INDEX.clear (index())

  let get a = INDEX.get (index()) a
  let find id = INDEX.find (index()) id

  include Collection
      (struct
        type t = M.key
        let syntax = publish_id (module I)
        let of_json js = INDEX.of_json (index()) js
        let to_json v = INDEX.to_json (index()) v
      end)

end

module type IdentifiedType =
sig
  type t
  val id : t -> int
end

module Identified(A : IdentifiedType)(I : Info) : Index with type t = A.t =
struct

  type index = (int,A.t) Hashtbl.t

  module TYPE : Datatype.S with type t = index =
    Datatype.Make
      (struct
        type t = index
        include Datatype.Undefined
        let reprs = [Hashtbl.create 0]
        let name = "Server.Data.Identified.Type." ^ I.name
        let mem_project = Datatype.never_any_project
      end)

  module STATE = State_builder.Ref(TYPE)
      (struct
        let name = "Server.Data.Identified.State." ^ I.name
        let dependencies = []
        let default () = Hashtbl.create 0
      end)

  let lookup () = STATE.get ()
  let clear () = Hashtbl.clear (lookup())

  let get = A.id
  let find id = Hashtbl.find (lookup()) id

  include Collection
      (struct
        type t = A.t
        let syntax = publish_id (module I)
        let to_json a = `Int (get a)
        let of_json js =
          let k = Ju.to_int js in
          try find k
          with Not_found -> failure "[%s] No registered id #%d" I.name k
      end)

end

(* -------------------------------------------------------------------------- *)
