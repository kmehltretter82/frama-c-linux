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
type message = {
 text: (string [@default ""]);
 messageId: (string [@default ""]);
 richText: (string [@default ""]);
 richMessageId: (string [@default ""]);
 arguments: (string list [@default []]);
}[@@deriving yojson]

let no_msg =
  { text = "";
    messageId = "";
    richText = "";
    richMessageId = "";
    arguments = [];
  }

type fileLocation = {
  uri: string;
  uriBaseId: (string [@default ""])
 }[@@deriving yojson]
let unknown_file = { uri = ""; uriBaseId = "" }

type fileContent =
  | Text of string [@name "text"]
  | Binary of string [@name "binary"]
[@@deriving yojson]

let no_file_content = Text ""

type region = {
  startLine: (int [@default 0]);
  startColumn: (int [@default 0]);
  endLine: (int [@default 0]);
  endColumn: (int [@default 0]);
  charOffset: (int [@default 0]);
  charLength: (int [@default 0]);
  byteOffset: (int [@default 0]);
  byteLength: (int [@default 0]);
  snippet: (fileContent [@default no_file_content]);
  message: (message [@default no_msg])
}[@@deriving yojson]

let no_region = {
  startLine = 0;
  startColumn = 0;
  endLine = 0;
  endColumn = 0;
  charOffset = 0;
  charLength = 0;
  byteOffset = 0;
  byteLength = 0;
  snippet = no_file_content;
  message = no_msg;
}

type rectangle = {
  top: (float [@default 0.]);
  left: (float [@default 0.]);
  bottom: (float [@default 0.]);
  right: (float [@default 0.]);
  message: (message [@default no_msg]);
}
[@@deriving yojson]

type custom_properties = [ `Null | `Assoc of (string * Yojson.Safe.json) list ]
[@@deriving yojson]

type properties = {
  tags: string list;
  additional_properties: (custom_properties [@default `Null])
}
[@@deriving yojson]

let no_prop = { tags = []; additional_properties = `Null }

type physicalLocation = {
  id: (string [@default ""]);
  fileLocation: fileLocation;
  region: (region [@default no_region]);
  contextRegion: (region [@default no_region]);
}[@@deriving yojson]
let unknown_physicalLocation = {
  id = "";
  fileLocation = unknown_file;
  region = no_region;
  contextRegion = no_region;
}

type location = {
  physicalLocation: physicalLocation;
  fullyQualifiedLogicalName: (string [@default ""]);
  message: (message [@default no_msg]);
  annotations: (region list [@default []]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]
let no_loc = {
  physicalLocation = unknown_physicalLocation;
  fullyQualifiedLogicalName = "";
  message = no_msg;
  annotations = [];
  properties = no_prop
}

type stackFrame = {
  location: (location [@default no_loc]);
  stack_module: (string [@default ""])[@key "module"];
  threadId: (int [@default 0]);
  address: (int [@default 0]);
  offset: (int [@default 0]);
  parameters: (string list [@default []]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type stack = {
  message: (message [@default no_msg]);
  frames: stackFrame list;
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

let no_stack = {
  message = no_msg;
  frames = [];
  properties = no_prop
}

(* TODO: this type definition is unclear in the schema. *)
type additional_properties =
  { additionalProperties: string }[@@deriving yojson]

let no_additional_prop = { additionalProperties = "" }

type stl_importance =
  | Important [@name "important"]
  | Essential [@name "essential"]
  | Unimportant [@name "unimportant"]
[@@deriving yojson]

type threadFlowLocation = {
  step: int;
  location: (location [@default no_loc]);
  stack: (stack [@default no_stack]);
  kind: (string [@default ""]);
  tfl_module: (string [@default ""])[@key "module"];
  state: (additional_properties [@default no_additional_prop]);
  nestingLevel: (int [@default 0]);
  executionOrder: (int [@default 0]);
  timestamp: (string [@default ""]);
  importance: (stl_importance [@default Unimportant]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type threadFlow = {
  id: (string [@default ""]);
  message: (message [@default no_msg]);
  locations: threadFlowLocation list;
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type attachment = {
 description: (message [@default no_msg ]);
 fileLocation: fileLocation;
 regions: (region list [@default []]);
 rectangles: (rectangle list [@default []])
} [@@deriving yojson]

type codeFlow = {
  description: (message [@default no_msg]);
  threadFlows: threadFlow list;
  properties: (properties [@default no_prop]);
} [@@deriving yojson]

type sarif_exception = {
  kind: (string [@default ""]);
  message: (string [@default ""]);
  stack: (stack [@default no_stack]);
  innerExceptions: (sarif_exception list [@default []]);
}[@@deriving yojson]
let no_exn = { kind = ""; message = ""; stack = no_stack; innerExceptions = [] }

type notification_kind =
  | Note [@name "note"]
  | Warning [@name "warning"]
  | Error [@name "error"]
[@@deriving yojson]

type notification = {
  id: (string [@default ""]);
  ruleId: (string [@default ""]);
  physicalLocation: (physicalLocation [@default unknown_physicalLocation]);
  message: message;
  level: (notification_kind [@default Warning]);
  threadId: (int [@default 0]);
  time: (string [@default ""]);
  exn: (sarif_exception [@default no_exn]) [@key "exception"];
  properties: (properties [@default no_prop])
}[@@deriving yojson]

type tool = {
  name: string;
  fullName: (string [@default ""]);
  version: (string [@default ""]);
  semanticVersion: (string [@default ""]);
  fileVersion: (string [@default ""]);
  downloadUri: (string [@default ""]);
  sarifLoggerVersion: (string [@default ""]);
  language: (string [@default "en-US"]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

let no_tool = {
  name = "";
  fullName = "";
  version = "";
  semanticVersion = "";
  fileVersion = "";
  downloadUri = "";
  sarifLoggerVersion = "";
  language = "";
  properties = no_prop;
}

type invocation = {
 commandLine: string;
 arguments: string list;
 responseFiles: (fileLocation list [@default []]);
 attachments: (attachment list [@default []]);
 startTime: (string [@default ""]);
 endTime: (string [@default ""]);
 exitCode: int;
 toolNotifications: (notification list [@default []]);
 configurationNotifications: (notification list [@default []]);
 exitCodeDescription: (string [@default ""]);
 exitSignalName: (string [@default ""]);
 exitSignalNumber: (int [@default 0]);
 processStartFailureMessage: (string [@default ""]);
 toolExecutionSuccessful: bool;
 machine: (string [@default ""]);
 account: (string [@default ""]);
 processId: (int [@default 0]);
 executableLocation: (fileLocation [@default unknown_file]);
 workingDirectory: (fileLocation [@default unknown_file]);
 environmentVariables: (additional_properties [@default no_additional_prop]);
 stdin: (fileLocation [@default unknown_file]);
 stdout: (fileLocation [@default unknown_file]);
 stderr: (fileLocation [@default unknown_file]);
 stdoutStderr: (fileLocation [@default unknown_file]);
 properties: (properties [@default no_prop]);
}[@@deriving yojson]

let std_invocation = {
  commandLine = "/bin/cat";
  arguments = [];
  responseFiles = [];
  attachments = [];
  startTime = "";
  endTime = "";
  exitCode = 0;
  toolNotifications = [];
  configurationNotifications = [];
  exitCodeDescription = "";
  exitSignalName = "";
  exitSignalNumber = 0;
  processStartFailureMessage = "";
  toolExecutionSuccessful = true;
  machine = "";
  account = "";
  processId = 0;
  executableLocation = unknown_file;
  workingDirectory = unknown_file;
  environmentVariables = no_additional_prop;
  stdin = unknown_file;
  stdout = unknown_file;
  stderr = unknown_file;
  stdoutStderr = unknown_file;
  properties = no_prop;
}

type conversion = {
  tool: tool;
  invocation: (invocation [@default std_invocation]);
  analysisToolLogFiles: (fileLocation [@default unknown_file]);
} [@@deriving yojson]

let no_conversion = {
  tool = no_tool;
  invocation = std_invocation;
  analysisToolLogFiles = unknown_file;
}

type edge = {
  id: string;
  label: (message [@default no_msg]);
  sourceNodeId: string;
  targetNodeId: string;
  properties: (properties [@default no_prop])
} [@@deriving yojson]

type node =
  { id: string;
    label: (string [@default ""]);
    location: (location [@default no_loc]);
    children: (node list [@default []]);
    properties: (properties [@default no_prop]);
  }[@@deriving yojson]

type edge_traversal = {
  edgeId: string;
  message: (message [@default no_msg]);
  finalState: (additional_properties [@default no_additional_prop]);
  stepOverEdgeCount: (int [@default 0]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type role =
  | AnalysisTarget [@name "analysisTarget"]
  | Attachment [@name "attachment"]
  | ResponseFile [@name "responseFile"]
  | ResultFile [@name "resultFile"]
  | StandardStrem [@name "standardStream"]
  | TraceFile [@name "traceFile"]
  | UnmodifiedFile [@name "unmodifiedFile"]
  | ModifiedFile [@name "modifiedFile"]
  | AddedFile [@name "addedFile"]
  | DeletedFile [@name "deletedFile"]
  | RenamedFile [@name "renamedFile"]
  | UncontrolledFile [@name "uncontrolledFile"]
[@@deriving yojson]

type hash = {
  value: string;
  algorithm: string
} [@@deriving yojson]

type graph = {
  id : string;
  description: (message [@default no_msg]);
  nodes: node list;
  edges: edge list;
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type graph_dictionary =
  [ `Null | `Assoc of (string * graph) list ][@@deriving yojson]
let no_graph = `Null

type graphTraversal = {
  graphId: string;
  description: (message [@default no_msg]);
  initialState: (additional_properties [@default no_additional_prop]);
  edgeTraversals: edge_traversal list;
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type replacement = {
  deletedRegion: region;
  insertedContent: (fileContent [@default no_file_content])
}[@@deriving yojson]

type file = {
  fileLocation: (fileLocation [@default unknown_file]);
  parentKey: (string [@default ""]);
  offset: (int [@default 0]);
  length: (int [@default 0]);
  roles: (role list [@default []]);
  mimeType: (string [@default ""]);
  contents: (fileContent [@default no_file_content]);
  encoding: (string [@default ""]);
  hashes: (hash list [@default []]);
  lastModifiedTime: (string [@default ""]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

type fileChange = {
  fileLocation: fileLocation;
  replacements: replacement list
}[@@deriving yojson]

type fix = {
  description: (message [@defaut no_msg]);
  fileChanges: fileChange list;
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

type logicalLocation = {
  name: string;
  fullyQualifiedName: string;
  decoratedName: string;
  parentKey: string;
  kind: string;
}[@@deriving yojson]

type ruleConfigLevel =
  | Note [@name "note"]
  | Warning [@name "warning"]
  | Error [@name "error"]
  | Open [@name "open"]
[@@deriving yojson]

type ruleConfiguration = {
  enabled: (bool [@default false]);
  defaultLevel: (ruleConfigLevel [@default Open]);
  parameters: (properties [@default no_prop])
}[@@deriving yojson]

let std_rule_config = {
  enabled = false;
  defaultLevel = Open;
  parameters = no_prop;
}

type rule = {
  id: (string [@default ""]);
  name: (string [@default ""]);
  shortDescription: (message [@default no_msg]);
  fullDescription: (message [@default no_msg]);
  messageStrings: (additional_properties [@default no_additional_prop]);
  richMessageStrings: (additional_properties [@default no_additional_prop]);
  configuration: (ruleConfiguration [@default std_rule_config]);
  helpUri: (string [@default ""]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

let no_rule = {
  id = "";
  name = "";
  shortDescription = no_msg;
  fullDescription = no_msg;
  messageStrings = no_additional_prop;
  richMessageStrings = no_additional_prop;
  configuration = std_rule_config;
  helpUri = "";
  properties = no_prop;
}

type resources = {
  messageStrings: (additional_properties [@default no_additional_prop]);
  rules: (rule [@default no_rule]);
}[@@deriving yojson]

let no_resources = { messageStrings = no_additional_prop; rules = no_rule }

type result_level =
  | NotApplicable [@name "notApplicable"]
  | Pass [@name "pass"]
  | Note [@name "note"]
  | Warning [@name "warning"]
  | Error [@name "error"]
[@@deriving yojson]

type result_suppressionState =
  | SuppressedInSource [@name "suppressedInSource"]
  | SuppressedExternally [@name "suppressedExternally"]
[@@deriving yojson]

type result_baselineState =
  | New [@name "new"]
  | Existing [@name "existing"]
  | Absent [@name "absent"]
[@@deriving yojson]

type result = {
  ruleId: (string [@default ""]);
  level: (result_level [@default NotApplicable]);
  message: (message [@default no_msg]);
  analysisTarget: (fileLocation [@default unknown_file]);
  locations: (location list [@default []]);
  instanceGuid: (string [@default ""]);
  correlationGuid: (string [@default ""]);
  occurenceCount: (int [@default 1]);
  partialFingerprints: (additional_properties [@default no_additional_prop]);
  fingerprints: (additional_properties [@default no_additional_prop]);
  stacks: (stack list [@default []]);
  codeFlows: (codeFlow list [@default []]);
  graphs: (graph_dictionary [@default no_graph]);
  graphTraversals: (graphTraversal list [@default []]);
  relatedLocations: (location list [@default []]);
  suppressionStates: (result_suppressionState list [@default []]);
  baselineState: (result_baselineState [@default Absent]);
  attachments: (attachment list [@default []]);
  workItemsUris: (string list [@default []]);
  conversionProvenance: (physicalLocation list [@default[]]);
  fixes: (fix list [@default []]);
  properties: (properties [@default no_prop])
}[@@deriving yojson]

type versionControlDetails = {
  uri: string;
  revisionId: (string [@default ""]);
  branch: (string [@default ""]);
  tag: (string [@default ""]);
  timestamp: (string [@default ""]);
  properties: (properties [@default no_prop]);
}[@@deriving yojson]

(** TODO: `Assoc should take as argument a json rep of a file *)
type file_dictionary =
  [ `Null | `Assoc of string * Yojson.Safe.json][@@deriving yojson]
let no_file = `Null

(** TODO: values are logicalLocation *)
type logical_loc_dict =
  [ `Null | `Assoc of string * logicalLocation][@@deriving yojson]
let no_location = `Null

type columnKind =
  | Utf16CodeUnits [@name "utf16CodeUnits"]
  | UnicodeCodePoints [@name "unicodeCodePoints"]
[@@deriving yojson]

type run = {
  tool: tool;
  invocations: (invocation list [@default []]);
  conversion: (conversion [@default no_conversion]);
  versionControlProvenance: (versionControlDetails list [@default []]);
  originalUriBaseIds: (additional_properties [@default no_additional_prop]);
  files: (file_dictionary [@default no_file]);
  logicalLocations: (logical_loc_dict [@default no_location]);
  graphs: (graph_dictionary [@default no_graph]);
  results: (result list [@default []]);
  resources: (resources [@default no_resources]);
  instanceGuid: (string [@default ""]);
  correlationGuid: (string [@default ""]);
  logicalId: (string [@default ""]);
  description: (message [@default no_msg]);
  automationLogicalId: (string [@default ""]);
  baselineInstanceGuid: (string [@default ""]);
  architecture: (string [@default ""]);
  richMessageMimeType: (string [@default "text/markdown;variant=GFM" ]);
  redactionToken: (string [@default ""]);
  defaultFileEncoding: (string [@default "utf-8"]);
  columnKind: (columnKind [@default UnicodeCodePoints]);
  properties: (properties [@default no_prop]);
}
[@@deriving yojson]

type schema = {
  schema: (uri [@default Sarif_github]) [@key "$schema"];
  version: (version [@default V2_0_0]);
  runs: run list
} [@@deriving yojson]
