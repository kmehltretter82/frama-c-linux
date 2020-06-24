(* -------------------------------------------------------------------------- *)
(* --- Frama-C TypeScript API Generator                                   --- *)
(* -------------------------------------------------------------------------- *)

module Self = Plugin.Register
  (struct
    let name = "Server TypeScript API"
    let shortname = "server-tsc"
    let help = "Generate TypeScript API for Server"
  end)

module TSC = Self.Action
    (struct
      let option_name = "-server-tsc"
      let help = "Generate TypeScript API"
    end)

module OUT = Self.String
    (struct
      let option_name = "-server-tsc-out"
      let arg_name = "dir"
      let default = "api"
      let help = "Output directory (default is './api')"
    end)

module Md = Markdown
module Pkg = Server.Package

(* -------------------------------------------------------------------------- *)
(* --- TS Utils                                                           --- *)
(* -------------------------------------------------------------------------- *)

let keywords = [
  "break"; "case"; "catch"; "class"; "const"; "continue"; "debugger";
  "default"; "delete"; "do"; "else"; "enum"; "export"; "extends"; "false";
  "finally"; "for"; "function"; "if"; "import"; "in"; "instanceof"; "new";
  "null"; "return"; "super"; "switch"; "this"; "throw"; "true"; "try";
  "typeof"; "var"; "void"; "while"; "with"; "as"; "implements"; "interface";
  "let"; "package"; "private"; "protected"; "public"; "static"; "yield"; "any";
  "boolean"; "constructor"; "declare"; "get"; "module"; "require"; "number";
  "set"; "string"; "symbol"; "type"; "from"; "of";
  "Json"; "Compare"; "Server"; "State";
]

let pp_descr = Md.pp_text ?page:None

let name_of_kind = function
  | `GET -> "GET"
  | `SET -> "SET"
  | `EXEC -> "EXEC"

let makeDescr ?(indent="") fmt descr =
  if descr <> [] then
    Format.fprintf fmt "%s/** @[<hov 0>%a@] */@." indent pp_descr descr

let getSelf = function
  | None -> Self.fatal "Unexpected recursive type"
  | Some id -> id

(* -------------------------------------------------------------------------- *)
(* --- Jtype Generator                                                    --- *)
(* -------------------------------------------------------------------------- *)

let makeJtype ?self ~names =
  let open Pkg in
  let pp_ident fmt id =
    match IdMap.find id names with
    | name -> Format.pp_print_string fmt name
    | exception Not_found -> Self.abort "Undefined '%a'" pp_ident id in
  let rec pp fmt = function
    | Jany -> Format.pp_print_string fmt "Json.json"
    | Jself -> Format.pp_print_string fmt (getSelf self).name
    | Jnull -> Format.pp_print_string fmt "null"
    | Jnumber -> Format.pp_print_string fmt "number"
    | Jboolean -> Format.pp_print_string fmt "boolean"
    | Jstring | Jalpha -> Format.pp_print_string fmt "string"
    | Jkey kd -> Format.fprintf fmt "Json.Key<'#%s'>" kd
    | Jindex kd -> Format.fprintf fmt "Json.Index<'#%s'>" kd
    | Jdict(kd,js) -> Format.fprintf fmt "Json.Dict<'#%s',%a>" kd pp js
    | Jdata id | Jenum id -> pp_ident fmt id
    | Joption js -> Format.fprintf fmt "%a |@ undefined" pp js
    | Jtuple js ->
      Pretty_utils.pp_list ~pre:"@[<hov 2>[ " ~sep:",@ " ~suf:"@ ]@]" pp fmt js
    | Junion js ->
      Pretty_utils.pp_list ~pre:"@[<hov 0>" ~sep:" |@ " ~suf:"@]" protect fmt js
    | Jrecord fjs ->
      Pretty_utils.pp_list ~pre:"@[<hov 2>{ " ~sep:",@ " ~suf:"@ }@]" field fmt fjs
    | Jarray js | Jlist js -> Format.fprintf fmt "%a[]" protect js
  and protect fmt js = match js with
    | Junion _ | Joption _ -> Format.fprintf fmt "@[<hov 2>(%a)@]" pp js
    | _ -> pp fmt js
  and field fmt (fd,js) = Format.fprintf fmt "@[<hov 4>%s:@ %a@]" fd pp js
  in pp

(* -------------------------------------------------------------------------- *)
(* --- Jtype Decoder                                                      --- *)
(* -------------------------------------------------------------------------- *)

let jprim fmt name = Format.fprintf fmt "Json.%s" name
let jkey fmt kd = Format.fprintf fmt "Json.jKey('#%s')" kd
let jindex fmt kd = Format.fprintf fmt "Json.jIndex('#%s')" kd

let jcall names fmt id =
  try Format.pp_print_string fmt (Pkg.IdMap.find id names)
  with Not_found -> Self.abort "Undefined identifier '%a'" Pkg.pp_ident id

let jsafe ~safe msg pp fmt d =
  if safe then
    Format.fprintf fmt "@[<hov 2>Json.jFail(@,%a,@,'%s expected')@]" pp d msg
  else
    pp fmt d

let jtry ~safe pp fmt d =
  if safe then
    pp fmt d
  else
    Format.fprintf fmt "@[<hov 2>Json.jTry(@,%a)@]" pp d

let jenum names fmt id = Format.fprintf fmt "Json.jEnum(%a)" (jcall names) id

let junion ~jtype ~makeLoose fmt jts =
  begin
    Format.fprintf fmt "@[<hv 0>@[<hv 2>Json.jUnion<%a>("
      jtype (Pkg.Junion jts) ;
    List.iter
      (fun js -> Format.fprintf fmt "@ @[<hov 2>%a@]," makeLoose js) jts ;
    Format.fprintf fmt "@]@,)@]" ;
  end

let jrecord ~makeSafe fmt jts =
  begin
    Format.fprintf fmt "@[<hv 0>@[<hv 2>Json.jObject({" ;
    List.iter
      (fun (fd,js) ->
         Format.fprintf fmt "@ @[<hov 2>%s: %a@]," fd makeSafe js) jts ;
    Format.fprintf fmt "@]@,})@]" ;
  end

let jtuple ~makeSafe fmt jts =
  begin
    let name = match List.length jts with
      | 2 -> "jPair"
      | 3 -> "jTriple"
      | 4 -> "jTuple4"
      | 5 -> "jTuple5"
      | n -> Self.fatal "No jTuple%d defined" n
    in
    Format.fprintf fmt "@[<hv 0>@[<hv 2>Json.%s(" name ;
    List.iter
      (fun js -> Format.fprintf fmt "@ @[<hov 2>%a@]," makeSafe js) jts ;
    Format.fprintf fmt "@]@,)@]" ;
  end

let rec makeDecoder ~safe ?self ~names fmt js =
  let open Pkg in
  let makeSafe = makeDecoder ?self ~names ~safe:true in
  let makeLoose = makeDecoder ?self ~names ~safe:false in
  match js with
  | Jany -> jprim fmt "jAny"
  | Jnull -> jprim fmt "jNull"
  | Jboolean -> jsafe ~safe "Boolean" jprim fmt "jBoolean"
  | Jnumber -> jsafe ~safe "Number" jprim fmt "jNumber"
  | Jstring | Jalpha -> jsafe ~safe "String" jprim fmt "jString"
  | Jkey kd -> jsafe ~safe ("#" ^ kd) jkey fmt kd
  | Jindex kd -> jsafe ~safe ("#" ^ kd) jindex fmt kd
  | Jdata id -> jcall names fmt (Pkg.Derived.decode ~safe id)
  | Jenum id -> jsafe ~safe (Pkg.name_of_ident id) (jenum names) fmt id
  | Jself -> jcall names fmt (Pkg.Derived.decode ~safe (getSelf self))
  | Joption js -> makeLoose fmt js
  | Jdict(kd,js) ->
    Format.fprintf fmt "@[<hov 2>Json.jDictionary('#%s',@,%a)@]" kd makeLoose js
  | Jlist js ->
    Format.fprintf fmt "@[<hov 2>Json.jList(%a)@]" makeLoose js
  | Jarray js ->
    if safe
    then Format.fprintf fmt "@[<hov 2>Json.jArray(%a)@]" makeSafe js
    else Format.fprintf fmt "@[<hov 2>Json.jTry(jArray(%a))@]" makeSafe js
  | Junion jts ->
    let jtype = makeJtype ?self ~names in
    jsafe ~safe "Union" (junion ~jtype ~makeLoose) fmt jts
  | Jrecord jfs -> jtry ~safe (jrecord ~makeSafe) fmt jfs
  | Jtuple jts -> jtry ~safe (jtuple ~makeSafe) fmt jts

let makeRootDecoder ~safe ~self ~names fmt js =
  let open Pkg in
  match js with
  | Joption _ | Jdict _ | Jlist _ when safe ->
    jcall names fmt (Pkg.Derived.loose self)
  | Jrecord _ | Jtuple _ | Jarray _ when not safe ->
    Format.fprintf fmt "Json.jTry(%a)"
      (jcall names) (Pkg.Derived.safe self)
  | Junion _ when safe ->
    Format.fprintf fmt "Json.jFail(%a,'%s expected')"
      (jcall names) (Pkg.Derived.loose self)
      (String.capitalize_ascii self.name)
  | _ -> makeDecoder ~safe ~self ~names fmt js

(* -------------------------------------------------------------------------- *)
(* --- Parameter Decoder                                                  --- *)
(* -------------------------------------------------------------------------- *)

let typeOfParam = function
  | Pkg.P_value js -> js
  | Pkg.P_named fjs ->
    let field fd = fd.Pkg.fd_name , fd.Pkg.fd_type in
    Jrecord (List.map field fjs)

(* -------------------------------------------------------------------------- *)
(* --- Jtype Order                                                        --- *)
(* -------------------------------------------------------------------------- *)

let makeOrder ~self ~names fmt js =
  let open Pkg in
  let rec pp fmt = function
    | Jnull -> Format.pp_print_string fmt "Compare.equal"
    | Jalpha -> Format.pp_print_string fmt "Compare.alpha"
    | Jnumber | Jstring | Jboolean | Jkey _ | Jindex _
      -> Format.pp_print_string fmt "Compare.primitive"
    | Jself -> jcall names fmt (Pkg.Derived.order self)
    | Jdata id -> jcall names fmt (Pkg.Derived.order id)
    | Joption js ->
      Format.fprintf fmt "@[<hov 2>Compare.defined(@,%a)@]" pp js
    | Jany | Junion _ -> (* Can not find a better solution *)
      Format.fprintf fmt "Compare.structural"
    | Jenum id ->
      Format.fprintf fmt "@[<hov 2>Compare.byEnym(@,%a)@]" (jcall names) id
    | Jlist js | Jarray js ->
      Format.fprintf fmt "@[<hov 2>Compare.array(@,%a)@]" pp js
    | Jtuple jts ->
      let name = match List.length jts with
        | 2 -> "pair"
        | 3 -> "triple"
        | 4 -> "tuple4"
        | 5 -> "tuple5"
        | n -> Self.abort "No comparison for %d-tuples" n in
      Format.fprintf fmt "@[<hv 0>@[<hv 2>Compare.%s(" name ;
      List.iter (fun js -> Format.fprintf fmt "@,%a," pp js) jts ;
      Format.fprintf fmt "@]@,)@]" ;
    | Jrecord jfs ->
      Format.fprintf fmt "@[<hv 0>@[<hv 2>Compare.byFields({" ;
      List.iter
        (fun (fd,js) -> Format.fprintf fmt "@ @[<hov 2>%s: %a,@]" fd pp js) jfs ;
      Format.fprintf fmt "@]@ })@]" ;
    | Jdict(kd,js) ->
      let jtype fmt js = makeJtype ~names fmt js in
      Format.fprintf fmt
        "@[<hov 2>Compare.dictionary<@,Json.dict<'#%s'@,%a>>(@,%a)@]"
        kd jtype js pp js
  in pp fmt js

(* -------------------------------------------------------------------------- *)
(* --- Declaration Generator                                              --- *)
(* -------------------------------------------------------------------------- *)

let makeDeclaration fmt names d =
  let open Pkg in
  Format.pp_print_newline fmt () ;
  makeDescr fmt d.d_descr ;
  let self = d.d_ident in
  let jtype = makeJtype ~self ~names in
  match d.d_kind with

  | D_type js ->
    Format.fprintf fmt "@[<hv 2>export type %s =@ %a;@]@\n" self.name jtype js

  | D_record fjs ->
    Format.fprintf fmt "export interface %s {@\n" self.name ;
    List.iter
      (fun { fd_name = fd ; fd_type = js ; fd_descr = doc } ->
         makeDescr ~indent:"  " fmt doc ;
         match js with
         | Joption js ->
           Format.fprintf fmt "  @[<hov 2>%s?: %a;@]@\n" fd jtype js
         | _ ->
           Format.fprintf fmt "  @[<hov 2>%s: %a;@]@\n" fd jtype js
      ) fjs ;
    Format.fprintf fmt "}@\n"

  | D_enum tgs ->
    Format.fprintf fmt "export enum %s {@\n" self.name ;
    List.iter
      (fun { tg_name = tag ; tg_descr = doc } ->
         makeDescr ~indent:"  " fmt doc ;
         Format.fprintf fmt "  %s = '%s';@\n" tag tag ;
      ) tgs ;
    Format.fprintf fmt "}@\n"

  | D_signal ->
    Format.fprintf fmt "export const %s: Server.Signal = {@\n" self.name ;
    Format.fprintf fmt "  name: '%s',@\n" (Pkg.name_of_ident d.d_ident) ;
    Format.fprintf fmt "};@\n"

  | D_request rq ->
    let kind = name_of_kind rq.rq_kind in
    let prefix = String.capitalize_ascii (String.lowercase_ascii kind) in
    let input = typeOfParam rq.rq_input in
    let output = typeOfParam rq.rq_output in
    let makeParam fmt js = makeDecoder ~safe:false ~names fmt js in
    Format.fprintf fmt
      "@[<hov 2>export const %s: Server.%sRequest<@,%a,@,%a@,> = {@]@\n"
      self.name prefix jtype input jtype output ;
    Format.fprintf fmt "  kind: Server.RqKind.%s,@\n" kind ;
    Format.fprintf fmt "  name:   '%s',@\n" (Pkg.name_of_ident d.d_ident) ;
    Format.fprintf fmt "  input:  %a,@\n" makeParam input ;
    Format.fprintf fmt "  output: %a,@\n" makeParam output ;
    Format.fprintf fmt "};@\n"

  | D_value js ->
    Format.fprintf fmt
      "@[<hov 2>export const %s: State.Value<@,%a@,> = {@]@\n"
      self.name jtype js ;
    Format.fprintf fmt "  name: '%s',@\n" (Pkg.name_of_ident self) ;
    Format.fprintf fmt "  signal: %a,@\n"
      (jcall names) (Pkg.Derived.signal self) ;
    Format.fprintf fmt "  getter: %a,@\n"
      (jcall names) (Pkg.Derived.getter self) ;
    Format.fprintf fmt "};@\n"

  | D_state js ->
    Format.fprintf fmt
      "@[<hov 2>export const %s: State.State<@,%a@,> = {@]@\n"
      self.name jtype js ;
    Format.fprintf fmt "  name: '%s',@\n" (Pkg.name_of_ident self) ;
    Format.fprintf fmt "  signal: %a,@\n"
      (jcall names) (Pkg.Derived.signal self) ;
    Format.fprintf fmt "  getter: %a,@\n"
      (jcall names) (Pkg.Derived.getter self) ;
    Format.fprintf fmt "  setter: %a,@\n"
      (jcall names) (Pkg.Derived.setter self) ;
    Format.fprintf fmt "};@\n"

  | D_array { arr_key ; arr_kind } ->
    let data = Pkg.Derived.data self in
    Format.fprintf fmt
      "@[<hov 2>export const %s: State.Array<@,'#%s',@,%a@,> = {@]@\n"
      self.name arr_kind (jcall names) data ;
    Format.fprintf fmt "  name: '%s',@\n" (Pkg.name_of_ident self) ;
    Format.fprintf fmt "  key: '%s',@\n" arr_key ;
    Format.fprintf fmt "  signal: %a,@\n"
      (jcall names) (Pkg.Derived.signal self) ;
    Format.fprintf fmt "  fetch: %a,@\n"
      (jcall names) (Pkg.Derived.fetch self) ;
    Format.fprintf fmt "  reload: %a,@\n"
      (jcall names) (Pkg.Derived.reload self) ;
    Format.fprintf fmt "};@\n"

  | D_safe(id,js) ->
    Format.fprintf fmt
      "@[<hov 2>export const %s: Json.Safe<@,%a@,> =@ %a;@]\n"
      self.name (jcall names) id
      (makeRootDecoder ~safe:true ~self:id ~names) js

  | D_loose(id,js) ->
    Format.fprintf fmt
      "@[<hov 2>export const %s: Json.Loose<@,%a@,> =@ %a;@]\n"
      self.name (jcall names) id
      (makeRootDecoder ~safe:false ~self:id ~names) js

  | D_order(id,js) ->
    Format.fprintf fmt
      "@[<hov 2>export const %s: Compare.Order<@,%a@,> =@ %a;@]\n"
      self.name (jcall names) id
      (makeOrder ~self:id ~names) js

(* -------------------------------------------------------------------------- *)
(* --- Package Generator                                                  --- *)
(* -------------------------------------------------------------------------- *)

let makePackage pkg name fmt =
  begin
    let open Pkg in
    Format.fprintf fmt "/* --- Generated Frama-C Server API --- */@\n@\n" ;
    Format.fprintf fmt "/**@\n   %s@\n" pkg.p_title ;
    if pkg.p_descr <> [] then
      Format.fprintf fmt "@\n   @[<hov 0>%a@]@\n@\n" pp_descr pkg.p_descr ;
    Format.fprintf fmt "   @@packageDocumentation@\n" ;
    Format.fprintf fmt "   @@module frama-c/%s@\n" name ;
    Format.fprintf fmt "*/@\n@." ;
    let names = Pkg.resolve ~keywords pkg in
    Format.fprintf fmt "import * as Json from 'dome/data/json';@\n" ;
    Format.fprintf fmt "import * as Compare from 'dome/data/compare';@\n" ;
    Format.fprintf fmt "import * as Server from 'frama-c/server';@\n" ;
    Format.fprintf fmt "import * as State from 'frama-c/states';@\n" ;
    Format.pp_print_newline fmt () ;
    Pkg.IdMap.iter
      (fun id name ->
         if id.plugin <> pkg.p_plugin ||
            id.package <> pkg.p_package
         then
           let pkg = Pkg.name_of_pkg ~sep:"/" id.plugin id.package in
           if id.name = name then
             Format.fprintf fmt "import { %s } from 'api/%s';@\n"
               name pkg
           else
             Format.fprintf fmt "import { %s: %s } from 'api/%s';@\n"
               id.name name pkg
      ) names ;
    List.iter (makeDeclaration fmt names) pkg.p_content ;
    Format.pp_print_newline fmt () ;
    Format.fprintf fmt "/* ------------------------------------- */@." ;
  end

(* -------------------------------------------------------------------------- *)
(* --- Main Generator                                                     --- *)
(* -------------------------------------------------------------------------- *)

let generate () =
  begin
    Pkg.iter
      begin fun pkg ->
        Self.feedback "Package %a" Pkg.pp_pkgname pkg ;
        let name = Pkg.name_of_pkginfo ~sep:"/" pkg in
        let file = Printf.sprintf "%s/%s/index.ts" (OUT.get ()) name in
        let dir = Filename.dirname file in
        if not (Sys.file_exists dir && Sys.is_directory dir) then
          Extlib.mkdir ~parents:true dir 0o755 ;
        Command.print_file file (makePackage pkg name) ;
      end
  end

let () = Db.Main.extend generate

(* -------------------------------------------------------------------------- *)
