(** OCaml representation for the sarif 2.0 schema. *)

(** ppx_deriving_yojson generates parser and printer that are recursive
    by default: we must thus silence spurious let rec warning (39). *)
[@@@ warning "-39"]

type uri =
  | Sarif_github [@name "https://github.com/oasis-tcs/sarif-spec/blob/master/Schemata/sarif-schema.json"]
[@@deriving yojson]

type version =
  | V2_0_0 [@name "2.0.0"]
[@@deriving yojson]

(* not defined yet *)
type message = { __body: string }[@@deriving yojson]
let no_msg = { __body = "" }

type fileLocation = { __filename: string }[@@deriving yojson]
let unknown_file = { __filename = "" }

type region = { __line: int }[@@deriving yojson]

type rectangle = { __minx: int; __maxx: int; __miny: int; __maxy: int }
[@@deriving yojson]

type threadFlow = { __id: int }[@@deriving yojson]

type attachment = {
 description: (message [@default no_msg ]);
 fileLocation: fileLocation;
 regions: (region list [@default []]);
 rectangles: (rectangle list [@default []])
} [@@deriving yojson]

type custom_properties = [ `Null | `Assoc of (string * Yojson.Safe.json) list ]
[@@deriving yojson]

type properties = {
  tags: string list;
  additional_properties: (custom_properties [@default `Null])
}
[@@deriving yojson]

let no_prop = { tags = []; additional_properties = `Null }

type codeFlow = {
  description: (message [@default no_msg]);
  threadFlows: threadFlow list;
  properties: (properties [@default no_prop]);
} [@@deriving yojson]

type tool = { __toolname: string }[@@deriving yojson]

type invocation = { __cmdline: string list }[@@deriving yojson]
let std_invocation = { __cmdline = [] }

type conversion = {
  tool: tool;
  invocation: (invocation [@default std_invocation]);
  analysisToolLogFiles: (fileLocation [@default unknown_file]);
} [@@deriving yojson]

type edge = {
  id: string;
  label: (message [@default no_msg]);
  sourceNodeId: string;
  targetNodeId: string;
  properties: (properties [@default no_prop])
} [@@deriving yojson]

(* TODO: this type definition is unclear in the schema. *)
type finalState = { additionalProperties: string }[@@deriving yojson]

let no_state_info = { additionalProperties = "" }

type edge_traversal = {
  edgeId: string;
  message: (message [@default no_msg]);
  finalState: (finalState [@default no_state_info]);
  stepOverEdgeCount: (int [@default 0]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type stack = { __stack: string list }[@@deriving yojson]

type sarif_exception = {
  kind: string;
  message: string;
  stack: stack;
  innerExceptions: sarif_exception list
}[@@deriving yojson]

type externalFiles = {
  conversion: (fileLocation [@default unknown_file]);
  files: (fileLocation [@default unknown_file]);
  graphs: (fileLocation [@default unknown_file]);
  invocations: (fileLocation list [@default []]);
  logicalLocations: (fileLocation [@default unknown_file]);
  resources: (fileLocation [@default unknown_file]);
  results: (fileLocation [@default unknown_file]);
}[@@deriving yojson]

type run = Nothing
[@@deriving yojson]

type schema = {
  schema: (uri [@default Sarif_github]) [@key "$schema"];
  version: (version [@default V2_0_0]);
  runs: run list
} [@@deriving yojson]
