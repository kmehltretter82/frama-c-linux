(** OCaml representation for the sarif 2.0 schema. *)

(** ppx_deriving_yojson generates parser and printer that are recursive
    by default: we must thus silence spurious let rec warning (39). *)
[@@@ warning "-39"]

module type Json_type = sig
  type t
  val of_yojson: Yojson.Safe.json -> t Ppx_deriving_yojson_runtime.error_or
  val to_yojson: t -> Yojson.Safe.json
end

module Json_dictionary(J: Json_type):
  Json_type with type t = (string * J.t) list =
struct
  type t = (string * J.t) list
  let bind x f = match x with Ok x -> f x | Error e -> Error e
  let bindret x f = bind x (fun x -> Ok (f x))
  let bind_pair f (s, x) = bindret (f x) (fun x -> (s, x))
  let one_step f acc x =
    bind acc (fun acc -> (bindret (f x) (fun x -> (x :: acc))))
  let bind_list l f =
    bindret (List.fold_left (one_step (bind_pair f)) (Ok []) l) List.rev
  let of_yojson = function
    | `Assoc l ->
      (match bind_list l J.of_yojson with
       | Error e -> Error ("dict." ^ e)
       | Ok _ as res -> res)
    | `Null -> Ok []
    | _ -> Error "dict"
  let to_yojson l =
    let json_l = List.map (fun (s, x) -> (s, J.to_yojson x)) l in
    `Assoc json_l
end

module Uri = struct
  type t =
    | Sarif_github [@name "https://github.com/oasis-tcs/sarif-spec/blob/master/Schemata/sarif-schema.json"]
    [@@deriving yojson]
end

module Version = struct
  type t =
    | V2_0_0 [@name "2.0.0"]
  [@@deriving yojson]
end

module Message = struct
  type t = {
    text: (string [@default ""]);
    messageId: (string [@default ""]);
    richText: (string [@default ""]);
    richMessageId: (string [@default ""]);
    arguments: (string list [@default []]);
  }[@@deriving yojson]

let default =
  { text = "";
    messageId = "";
    richText = "";
    richMessageId = "";
    arguments = [];
  }
end

module FileLocation = struct
  type t = {
    uri: string;
    uriBaseId: (string [@default ""])
  }[@@deriving yojson]

  let default = { uri = ""; uriBaseId = "" }
end

module FileContent = struct
type t =
  | Text of string [@name "text"]
  | Binary of string [@name "binary"]
[@@deriving yojson]

let default = Text ""
end

module Region = struct
type t = {
  startLine: (int [@default 0]);
  startColumn: (int [@default 0]);
  endLine: (int [@default 0]);
  endColumn: (int [@default 0]);
  charOffset: (int [@default 0]);
  charLength: (int [@default 0]);
  byteOffset: (int [@default 0]);
  byteLength: (int [@default 0]);
  snippet: (FileContent.t [@default FileContent.default]);
  message: (Message.t [@default Message.default])
}[@@deriving yojson]

let default = {
  startLine = 0;
  startColumn = 0;
  endLine = 0;
  endColumn = 0;
  charOffset = 0;
  charLength = 0;
  byteOffset = 0;
  byteLength = 0;
  snippet = FileContent.default;
  message = Message.default;
}
end

module Rectangle = struct
  type t = {
    top: (float [@default 0.]);
    left: (float [@default 0.]);
    bottom: (float [@default 0.]);
    right: (float [@default 0.]);
    message: (Message.t [@default Message.default]);
}
[@@deriving yojson]
end

module Custom_properties =
  Json_dictionary(struct
    type t = Yojson.Safe.json
    let of_yojson x = Ok x
    let to_yojson x = x
  end)

module Properties = struct
  type tags = string list [@@deriving yojson]

  type t = {
    tags: tags;
    additional_properties: Custom_properties.t
  }

  let default = { tags = []; additional_properties = [] }

  let create additional_properties =
    let tags = List.map fst additional_properties in
    { tags; additional_properties }

  let of_yojson = function
    | `Null -> Ok default
    | `Assoc l ->
      (match List.assoc_opt "tags" l with
       | None -> Error "properties"
       | Some json ->
         (match tags_of_yojson json with
          | Ok tags ->
            let additional_properties = List.remove_assoc "tags" l in
            Ok { tags; additional_properties }
          | Error loc -> Error ("properties." ^ loc)))
    | _ -> Error "properties"

  let to_yojson { tags; additional_properties } =
    match tags with
    | [] -> `Null
    | _ -> `Assoc (("tags", tags_to_yojson tags)::additional_properties)
end

module PhysicalLocation = struct
  type t = {
    id: (string [@default ""]);
    fileLocation: FileLocation.t;
    region: (Region.t [@default Region.default]);
    contextRegion: (Region.t [@default Region.default]);
  }[@@deriving yojson]

  let default = {
    id = "";
    fileLocation = FileLocation.default;
    region = Region.default;
    contextRegion = Region.default;
  }
end

module Location = struct
  type t = {
    physicalLocation: PhysicalLocation.t;
    fullyQualifiedLogicalName: (string [@default ""]);
    message: (Message.t [@default Message.default]);
    annotations: (Region.t list [@default []]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
  let default = {
    physicalLocation = PhysicalLocation.default;
    fullyQualifiedLogicalName = "";
    message = Message.default;
    annotations = [];
    properties = Properties.default;
  }
end

module StackFrame = struct
  type t = {
    location: (Location.t [@default Location.default]);
    stack_module: (string [@default ""])[@key "module"];
    threadId: (int [@default 0]);
    address: (int [@default 0]);
    offset: (int [@default 0]);
    parameters: (string list [@default []]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module Stack = struct
  type t = {
    message: (Message.t [@default Message.default]);
    frames: StackFrame.t list;
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]

  let default = {
    message = Message.default;
    frames = [];
    properties = Properties.default;
  }
end


module Additional_properties = struct
  include Json_dictionary(struct type t = string[@@deriving yojson] end)

  let default = []
end

module Stl_importance = struct
  type t =
    | Important [@name "important"]
    | Essential [@name "essential"]
    | Unimportant [@name "unimportant"]
  [@@deriving yojson]
end

module ThreadFlowLocation = struct
  type t = {
    step: int;
    location: (Location.t [@default Location.default]);
    stack: (Stack.t [@default Stack.default]);
    kind: (string [@default ""]);
    tfl_module: (string [@default ""])[@key "module"];
    state: (Additional_properties.t [@default Additional_properties.default]);
    nestingLevel: (int [@default 0]);
    executionOrder: (int [@default 0]);
    timestamp: (string [@default ""]);
    importance: (Stl_importance.t [@default Stl_importance.Unimportant]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module ThreadFlow = struct
  type t = {
    id: (string [@default ""]);
    message: (Message.t [@default Message.default]);
    locations: ThreadFlowLocation.t list;
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module Attachment = struct
  type t = {
    description: (Message.t [@default Message.default ]);
    fileLocation: FileLocation.t;
    regions: (Region.t list [@default []]);
    rectangles: (Rectangle.t list [@default []])
  } [@@deriving yojson]
end

module CodeFlow = struct
  type t = {
    description: (Message.t [@default Message.default]);
    threadFlows: ThreadFlow.t list;
    properties: (Properties.t [@default Properties.default]);
  } [@@deriving yojson]
end

module Sarif_exception = struct
type t = {
  kind: (string [@default ""]);
  message: (string [@default ""]);
  stack: (Stack.t [@default Stack.default]);
  innerExceptions: (t list [@default []]);
}[@@deriving yojson]

let default =
  {
    kind = "";
    message = "";
    stack = Stack.default;
    innerExceptions = []
  }
end

module Notification_kind = struct
  type t =
    | Note [@name "note"]
    | Warning [@name "warning"]
    | Error [@name "error"]
  [@@deriving yojson]
end

module Notification = struct
  type t = {
    id: (string [@default ""]);
    ruleId: (string [@default ""]);
    physicalLocation: (PhysicalLocation.t [@default PhysicalLocation.default]);
    message: Message.t;
    level: (Notification_kind.t [@default Notification_kind.Warning]);
    threadId: (int [@default 0]);
    time: (string [@default ""]);
    exn: (Sarif_exception.t [@default Sarif_exception.default])
        [@key "exception"];
    properties: (Properties.t [@default Properties.default])
  }[@@deriving yojson]
end

module Tool = struct
  type t = {
    name: string;
    fullName: (string [@default ""]);
    version: (string [@default ""]);
    semanticVersion: (string [@default ""]);
    fileVersion: (string [@default ""]);
    downloadUri: (string [@default ""]);
    sarifLoggerVersion: (string [@default ""]);
    language: (string [@default "en-US"]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]

  let create
      ~name
      ?(fullName="")
      ?(version="")
      ?(semanticVersion="")
      ?(fileVersion="")
      ?(downloadUri="")
      ?(sarifLoggerVersion="")
      ?(language="en-US")
      ?(properties=Properties.default)
      ()
    =
    { name; fullName; version; semanticVersion; fileVersion;
      downloadUri; sarifLoggerVersion; language; properties }

  let default = create ~name:"" ()

end

module Invocation = struct

type t =  {
    commandLine: string;
    arguments: string list;
    responseFiles: (FileLocation.t list [@default []]);
    attachments: (Attachment.t list [@default []]);
    startTime: (string [@default ""]);
    endTime: (string [@default ""]);
    exitCode: int;
    toolNotifications: (Notification.t list [@default []]);
    configurationNotifications: (Notification.t list [@default []]);
    exitCodeDescription: (string [@default ""]);
    exitSignalName: (string [@default ""]);
    exitSignalNumber: (int [@default 0]);
    processStartFailureMessage: (string [@default ""]);
    toolExecutionSuccessful: bool;
    machine: (string [@default ""]);
    account: (string [@default ""]);
    processId: (int [@default 0]);
    executableLocation: (FileLocation.t [@default FileLocation.default]);
    workingDirectory: (FileLocation.t [@default FileLocation.default]);
    environmentVariables:
      (Additional_properties.t [@default Additional_properties.default]);
    stdin: (FileLocation.t [@default FileLocation.default]);
    stdout: (FileLocation.t [@default FileLocation.default]);
    stderr: (FileLocation.t [@default FileLocation.default]);
    stdoutStderr: (FileLocation.t [@default FileLocation.default]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]

  let create
    ~commandLine
    ?(arguments = [])
    ?(responseFiles = [])
    ?(attachments = [])
    ?(startTime = "")
    ?(endTime = "")
    ?(exitCode = 0)
    ?(toolNotifications = [])
    ?(configurationNotifications = [])
    ?(exitCodeDescription = "")
    ?(exitSignalName = "")
    ?(exitSignalNumber = 0)
    ?(processStartFailureMessage = "")
    ?(toolExecutionSuccessful = true)
    ?(machine = "")
    ?(account = "")
    ?(processId = 0)
    ?(executableLocation = FileLocation.default)
    ?(workingDirectory = FileLocation.default)
    ?(environmentVariables = Additional_properties.default)
    ?(stdin = FileLocation.default)
    ?(stdout = FileLocation.default)
    ?(stderr = FileLocation.default)
    ?(stdoutStderr = FileLocation.default)
    ?(properties = Properties.default)
    ()
    =
    {
      commandLine;
      arguments;
      responseFiles;
      attachments;
      startTime;
      endTime;
      exitCode;
      toolNotifications;
      configurationNotifications;
      exitCodeDescription;
      exitSignalName;
      exitSignalNumber;
      processStartFailureMessage;
      toolExecutionSuccessful;
      machine;
      account;
      processId;
      executableLocation;
      workingDirectory;
      environmentVariables;
      stdin;
      stdout;
      stderr;
      stdoutStderr;
      properties;
    }

  let default = create ~commandLine:"/bin/true" ()

end

module Conversion = struct
  type t = {
    tool: Tool.t;
    invocation: (Invocation.t [@default Invocation.default]);
    analysisToolLogFiles: (FileLocation.t [@default FileLocation.default]);
  } [@@deriving yojson]

  let default = {
    tool = Tool.default;
    invocation = Invocation.default;
    analysisToolLogFiles = FileLocation.default;
  }
end

module Edge = struct
  type t  = {
    id: string;
    label: (Message.t [@default Message.default]);
    sourceNodeId: string;
    targetNodeId: string;
    properties: (Properties.t [@default Properties.default])
  } [@@deriving yojson]
end

module Node = struct
  type t = {
    id: string;
    label: (string [@default ""]);
    location: (Location.t [@default Location.default]);
    children: (t list [@default []]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module Edge_traversal = struct
  type t = {
    edgeId: string;
    message: (Message.t [@default Message.default]);
    finalState:
      (Additional_properties.t [@default Additional_properties.default]);
    stepOverEdgeCount: (int [@default 0]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module Role = struct
  type t =
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
end

module Hash = struct
  type t = {
    value: string;
    algorithm: string
  } [@@deriving yojson]
end

module Graph = struct
  type t = {
    id : string;
    description: (Message.t [@default Message.default]);
    nodes: Node.t list;
    edges: Edge.t list;
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module Graph_dictionary = Json_dictionary(Graph)

module GraphTraversal = struct
  type t = {
    graphId: string;
    description: (Message.t [@default Message.default]);
    initialState:
      (Additional_properties.t [@default Additional_properties.default]);
    edgeTraversals: Edge_traversal.t list;
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module Replacement = struct
  type t = {
    deletedRegion: Region.t;
    insertedContent: (FileContent.t [@default FileContent.default])
  }[@@deriving yojson]
end

module File = struct
  type t = {
    fileLocation: (FileLocation.t [@default FileLocation.default]);
    parentKey: (string [@default ""]);
    offset: (int [@default 0]);
    length: (int [@default 0]);
    roles: (Role.t list [@default []]);
    mimeType: (string [@default ""]);
    contents: (FileContent.t [@default FileContent.default]);
    encoding: (string [@default ""]);
    hashes: (Hash.t list [@default []]);
    lastModifiedTime: (string [@default ""]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module FileChange = struct
  type t = {
    fileLocation: FileLocation.t;
    replacements: Replacement.t list
  }[@@deriving yojson]
end

module Fix = struct
  type t = {
    description: (Message.t [@defaut Message.default]);
    fileChanges: FileChange.t list;
  }[@@deriving yojson]
end

module ExternalFiles = struct
  type t = {
    conversion: (FileLocation.t [@default FileLocation.default]);
    files: (FileLocation.t [@default FileLocation.default]);
    graphs: (FileLocation.t [@default FileLocation.default]);
    invocations: (FileLocation.t list [@default []]);
    logicalLocations: (FileLocation.t [@default FileLocation.default]);
    resources: (FileLocation.t [@default FileLocation.default]);
    results: (FileLocation.t [@default FileLocation.default]);
  }[@@deriving yojson]
end

module LogicalLocation = struct
  type t = {
    name: string;
    fullyQualifiedName: string;
    decoratedName: string;
    parentKey: string;
    kind: string;
  }[@@deriving yojson]
end

module RuleConfigLevel = struct
  type t =
    | Note [@name "note"]
    | Warning [@name "warning"]
    | Error [@name "error"]
    | Open [@name "open"]
  [@@deriving yojson]
end

module RuleConfiguration = struct
  type t = {
    enabled: (bool [@default false]);
    defaultLevel: (RuleConfigLevel.t [@default RuleConfigLevel.Open]);
    parameters: (Properties.t [@default Properties.default])
  }[@@deriving yojson]

  let default = {
    enabled = false;
    defaultLevel = RuleConfigLevel.Open;
    parameters = Properties.default;
  }
end

module Rule = struct
  type t = {
    id: (string [@default ""]);
    name: (string [@default ""]);
    shortDescription: (Message.t [@default Message.default]);
    fullDescription: (Message.t [@default Message.default]);
    messageStrings:
      (Additional_properties.t [@default Additional_properties.default]);
    richMessageStrings:
      (Additional_properties.t [@default Additional_properties.default]);
    configuration: (RuleConfiguration.t [@default RuleConfiguration.default]);
    helpUri: (string [@default ""]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]

  let default = {
    id = "";
    name = "";
    shortDescription = Message.default;
    fullDescription = Message.default;
    messageStrings = Additional_properties.default;
    richMessageStrings = Additional_properties.default;
    configuration = RuleConfiguration.default;
    helpUri = "";
    properties = Properties.default;
  }
end

module Rule_dictionary = Json_dictionary(Rule)

module Resources = struct
  type t = {
    messageStrings:
      (Additional_properties.t [@default Additional_properties.default]);
    rules: (Rule_dictionary.t [@default []]);
  }[@@deriving yojson]

  let default = {
    messageStrings = Additional_properties.default;
    rules = [] }
end

module Result_level = struct
  type t = 
    | NotApplicable [@name "notApplicable"]
    | Pass [@name "pass"]
    | Note [@name "note"]
    | Warning [@name "warning"]
    | Error [@name "error"]
  [@@deriving yojson]
end

module Result_suppressionState = struct
  type t =
    | SuppressedInSource [@name "suppressedInSource"]
    | SuppressedExternally [@name "suppressedExternally"]
  [@@deriving yojson]
end

module Result_baselineState = struct
  type t =
    | New [@name "new"]
    | Existing [@name "existing"]
    | Absent [@name "absent"]
  [@@deriving yojson]
end

(* we can't use Result here, as this would conflict with
   Ppx_deriving_yojson_runtime.Result that is opened by the
   code generated by Ppx_deriving_yojson. *)
module Sarif_result: Json_type = struct
  type t = {
    ruleId: (string [@default ""]);
    level: (Result_level.t [@default Result_level.NotApplicable]);
    message: (Message.t [@default Message.default]);
    analysisTarget: (FileLocation.t [@default FileLocation.default]);
    locations: (Location.t list [@default []]);
    instanceGuid: (string [@default ""]);
    correlationGuid: (string [@default ""]);
    occurenceCount: (int [@default 1]);
    partialFingerprints:
      (Additional_properties.t [@default Additional_properties.default]);
    fingerprints:
      (Additional_properties.t [@default Additional_properties.default]);
    stacks: (Stack.t list [@default []]);
    codeFlows: (CodeFlow.t list [@default []]);
    graphs: (Graph_dictionary.t [@default []]);
    graphTraversals: (GraphTraversal.t list [@default []]);
    relatedLocations: (Location.t list [@default []]);
    suppressionStates: (Result_suppressionState.t list [@default []]);
    baselineState:
      (Result_baselineState.t [@default Result_baselineState.Absent]);
    attachments: (Attachment.t list [@default []]);
    workItemsUris: (string list [@default []]);
    conversionProvenance: (PhysicalLocation.t list [@default[]]);
    fixes: (Fix.t list [@default []]);
    properties: (Properties.t [@default Properties.default])
  }[@@deriving yojson]
end

module VersionControlDetails = struct
  type t = {
    uri: string;
    revisionId: (string [@default ""]);
    branch: (string [@default ""]);
    tag: (string [@default ""]);
    timestamp: (string [@default ""]);
    properties: (Properties.t [@default Properties.default]);
  }[@@deriving yojson]
end

module File_dictionary = Json_dictionary(File)

module LogicalLocation_dictionary = Json_dictionary(LogicalLocation)

module ColumnKind = struct
  type t =
    | Utf16CodeUnits [@name "utf16CodeUnits"]
    | UnicodeCodePoints [@name "unicodeCodePoints"]
  [@@deriving yojson]
end

module Run = struct
  type t = {
    tool: Tool.t;
    invocations: (Invocation.t list [@default []]);
    conversion: (Conversion.t [@default Conversion.default]);
    versionControlProvenance: (VersionControlDetails.t list [@default []]);
    originalUriBaseIds:
      (Additional_properties.t [@default Additional_properties.default]);
    files: (File_dictionary.t [@default []]);
    logicalLocations: (LogicalLocation_dictionary.t [@default []]);
    graphs: (Graph_dictionary.t [@default []]);
    results: (Sarif_result.t list [@default []]);
    resources: (Resources.t [@default Resources.default]);
    instanceGuid: (string [@default ""]);
    correlationGuid: (string [@default ""]);
    logicalId: (string [@default ""]);
    description: (Message.t [@default Message.default]);
    automationLogicalId: (string [@default ""]);
    baselineInstanceGuid: (string [@default ""]);
    architecture: (string [@default ""]);
    richMessageMimeType: (string [@default "text/markdown;variant=GFM" ]);
    redactionToken: (string [@default ""]);
    defaultFileEncoding: (string [@default "utf-8"]);
    columnKind: (ColumnKind.t [@default ColumnKind.UnicodeCodePoints]);
    properties: (Properties.t [@default Properties.default]);
}
[@@deriving yojson]

let create
    ~tool
    ~invocations
    ?(conversion=Conversion.default)
    ?(versionControlProvenance=[])
    ?(originalUriBaseIds=Additional_properties.default)
    ?(files=[])
    ?(logicalLocations=[])
    ?(graphs=[])
    ?(results=[])
    ?(resources=Resources.default)
    ?instanceGuid
    ?correlationGuid
    ?logicalId
    ?(description=Message.default)
    ?automationLogicalId
    ?baselineInstanceGuid
    ?(architecture="")
    ?(richMessageMimeType="text/markdown;variant=GFM")
    ?(redactionToken="")
    ?(defaultFileEncoding="utf-8")
    ?(columnKind=ColumnKind.UnicodeCodePoints)
    ?(properties=Properties.default)
    ()
  =
  let instanceGuid =
    match instanceGuid with
    | Some guid -> guid
    | None -> failwith "use guid generation library"
  in
  let correlationGuid =
    match correlationGuid with
    | Some guid -> guid
    | None -> failwith "use guid generation library"
  in
  let logicalId =
    match logicalId with
    | Some id -> id
    | None -> failwith "use id generator"
  in
  let automationLogicalId =
    match automationLogicalId with
    | Some id -> id
    | None -> failwith "use id generator"
  in
  let baselineInstanceGuid =
    match baselineInstanceGuid with
    | Some guid -> guid
    | None -> failwith "use guid generation library"
  in
  {
    tool; invocations; conversion; versionControlProvenance; originalUriBaseIds;
    files; logicalLocations; graphs; results; resources; instanceGuid;
    correlationGuid; logicalId; description; automationLogicalId;
    baselineInstanceGuid; architecture; richMessageMimeType;
    redactionToken; defaultFileEncoding; columnKind; properties
  }
end

module Schema = struct
  type t = {
    schema: (Uri.t [@default Uri.Sarif_github]) [@key "$schema"];
    version: Version.t;
    runs: Run.t list
  } [@@deriving yojson]

  let create ?(schema=Uri.Sarif_github) ?(version=Version.V2_0_0) ~runs () =
    { schema; version; runs }
end
