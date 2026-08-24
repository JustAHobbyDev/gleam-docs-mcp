import gleam/dynamic.{type Dynamic}
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}
import gleam/result
import mcp_toolkit_gleam/core/jsonrpc

pub const protocol_version = "2024-11-05"

pub type McpError {
  McpParseError
  McpInvalidRequest
  McpMethodNotFound
  McpInvalidParams
  McpInternalError
  McpApplicationError(message: String)
}

pub type DecodeError {
  DecodeError(expected: String, found: String, path: List(String))
}

pub type Annotations {
  Annotations(audience: Option(List(Role)), priority: Option(Float))
}

pub type AudioContent {
  AudioContent(
    annotations: Option(Annotations),
    data: String,
    mime_type: String,
    type_: ContentType,
  )
}

pub type BlobResourceContents {
  BlobResourceContents(blob: String, mime_type: Option(String), uri: String)
}

pub type CallToolRequest(arguments) {
  CallToolRequest(name: String, arguments: Option(arguments))
}

pub fn decode_call_tool_request(
  data: Dynamic,
) -> Result(CallToolRequest(Dynamic), List(DecodeError)) {
  case is_map(data) {
    True -> {
      use name <- result.try(get_map_string(data, "name"))
      let arguments = case erl_get_map_value(data, "arguments") {
        Ok(value) -> Some(value)
        Error(_) -> None
      }
      Ok(CallToolRequest(name:, arguments:))
    }
    False ->
      Error([DecodeError(expected: "Map", found: "wrong type", path: [])])
  }
}

pub type ToolResultContent {
  TextToolContent(TextContent)
  ImageToolContent(ImageContent)
  AudioToolContent(AudioContent)
  ResourceToolContent(EmbeddedResource)
}

pub type CallToolResult {
  CallToolResult(
    meta: Option(Meta),
    content: List(ToolResultContent),
    is_error: Option(Bool),
  )
}

pub type Meta {
  Meta(progress_token: Option(ProgressToken))
}

pub type RequestId =
  jsonrpc.Id

pub type CancelledNotification {
  CancelledNotification(reason: Option(String), request_id: RequestId)
}

pub type ClientCapabilities {
  ClientCapabilities(
    roots: Option(ClientCapabilitiesRoots),
    sampling: Option(ClientCapabilitiesSampling),
  )
}

pub type ClientCapabilitiesRoots {
  ClientCapabilitiesRoots(list_changed: Option(Bool))
}

pub type ClientCapabilitiesSampling {
  ClientCapabilitiesSampling
}

pub type CompleteRequest {
  CompleteRequest(
    argument: CompleteRequestArgument,
    ref: CompleteRequestReference,
  )
}

pub type CompleteRequestArgument {
  CompleteRequestArgument(name: String, value: String)
}

pub type CompleteRequestReference {
  CompleteRequestPromptReference(PromptReference)
  CompleteRequestResourceReference(ResourceReference)
}

pub type CompleteResult {
  CompleteResult(meta: Option(Meta), completion: Completion)
}

pub type Completion {
  Completion(has_more: Option(Bool), total: Option(Int), values: List(String))
}

pub type ContentType {
  ContentTypeText
  ContentTypeImage
  ContentTypeAudio
  ContentTypeResource
}

pub type CreateMessageRequest(metadata) {
  CreateMessageRequest(
    include_context: Option(IncludeContext),
    max_tokens: Int,
    messages: List(SamplingMessage),
    metadata: Option(metadata),
    model_preferences: Option(ModelPreferences),
    stop_sequences: Option(List(String)),
    system_prompt: Option(String),
    temperature: Option(Int),
  )
}

pub type IncludeContext {
  IncludeAllServers
  IncludeNone
  IncludeThisServer
}

pub type CreateMessageResult {
  CreateMessageResult(
    meta: Option(Meta),
    content: MessageContent,
    model: String,
    role: Role,
    stop_reason: Option(String),
  )
}

pub type MessageContent {
  TextMessageContent(TextContent)
  ImageMessageContent(ImageContent)
  AudioMessageContent(AudioContent)
}

pub type EmbeddedResource {
  EmbeddedResource(
    annotations: Option(Annotations),
    resource: ResourceContents,
    type_: String,
  )
}

pub type ResourceContents {
  TextResource(TextResourceContents)
  BlobResource(BlobResourceContents)
}

pub type GetPromptRequest {
  GetPromptRequest(arguments: Option(List(#(String, String))), name: String)
}

pub type GetPromptResult {
  GetPromptResult(
    meta: Option(Meta),
    description: Option(String),
    messages: List(PromptMessage),
  )
}

pub type ImageContent {
  ImageContent(
    annotations: Option(Annotations),
    data: String,
    mime_type: String,
    type_: String,
  )
}

pub type Implementation {
  Implementation(name: String, version: String)
}

pub type InitializeRequest {
  InitializeRequest(
    capabilities: ClientCapabilities,
    client_info: Implementation,
    protocol_version: String,
  )
}

pub type InitializeResult {
  InitializeResult(
    meta: Option(Meta),
    capabilities: ServerCapabilities,
    instructions: Option(String),
    protocol_version: String,
    server_info: Implementation,
  )
}

pub type InitializedNotification {
  InitializedNotification(meta: Option(Meta))
}

pub type ProgressToken {
  ProgressTokenString(String)
  ProgressTokenInt(Int)
}

pub type ListRequest {
  ListRequest(cursor: Option(String))
}

pub type ListPromptsResult {
  ListPromptsResult(
    meta: Option(Meta),
    next_cursor: Option(String),
    prompts: List(Prompt),
  )
}

pub type ListResourceTemplatesResult {
  ListResourceTemplatesResult(
    meta: Option(Meta),
    next_cursor: Option(String),
    resource_templates: List(ResourceTemplate),
  )
}

pub type ListResourcesResult {
  ListResourcesResult(
    meta: Option(Meta),
    next_cursor: Option(String),
    resources: List(Resource),
  )
}

pub type ListRootsRequest {
  ListRootsRequestParams(meta: Option(Meta))
}

pub type ListRootsResult {
  ListRootsResult(meta: Option(Meta), roots: List(Root))
}

pub type ListToolsResult {
  ListToolsResult(
    meta: Option(Meta),
    next_cursor: Option(String),
    tools: List(Tool),
  )
}

pub type LoggingLevel {
  LevelAlert
  LevelCritical
  LevelDebug
  LevelEmergency
  LevelError
  LevelInfo
  LevelNotice
  LevelWarning
}

pub type LoggingMessageNotification(data) {
  LoggingMessageNotification(
    data: data,
    level: LoggingLevel,
    logger: Option(String),
  )
}

pub type ModelHint {
  ModelHint(name: Option(String))
}

pub type ModelPreferences {
  ModelPreferences(
    cost_priority: Option(Int),
    hints: Option(List(ModelHint)),
    intelligence_priority: Option(Int),
    speed_priority: Option(Int),
  )
}

pub type PingRequest {
  PingRequest(meta: Option(Meta))
}

pub type PingResult {
  PingResult
}

pub type ProgressNotification {
  ProgressNotification(
    message: Option(String),
    progress: Int,
    progress_token: ProgressToken,
    total: Option(Int),
  )
}

pub type Prompt {
  Prompt(
    arguments: Option(List(PromptArgument)),
    description: Option(String),
    name: String,
  )
}

pub type PromptArgument {
  PromptArgument(
    description: Option(String),
    name: String,
    required: Option(Bool),
  )
}

pub type PromptListChangedNotification {
  PromptListChangedNotification(meta: Option(Meta))
}

pub type PromptMessage {
  PromptMessage(content: PromptMessageContent, role: Role)
}

pub type PromptMessageContent {
  TextPromptContent(TextContent)
  ImagePromptContent(ImageContent)
  AudioPromptContent(AudioContent)
  ResourcePromptContent(EmbeddedResource)
}

pub type PromptReference {
  PromptReference(name: String, type_: String)
}

pub type ReadResourceRequest {
  ReadResourceRequest(uri: String)
}

pub type ReadResourceResult {
  ReadResourceResult(meta: Option(Meta), contents: List(ResourceContents))
}

pub type Resource {
  Resource(
    annotations: Option(Annotations),
    description: Option(String),
    mime_type: Option(String),
    name: String,
    size: Option(Int),
    uri: String,
  )
}

pub type ResourceListChangedNotification {
  ResourceListChangedNotification(meta: Option(Meta))
}

pub type ResourceReference {
  ResourceReference(type_: String, uri: String)
}

pub type ResourceTemplate {
  ResourceTemplate(
    annotations: Option(Annotations),
    description: Option(String),
    name: String,
    uri_template: String,
  )
}

pub type ResourceUpdatedNotification {
  ResourceUpdatedNotification(uri: String)
}

pub type Role {
  Assistant
  User
}

pub type Root {
  Root(name: Option(String), uri: String)
}

pub type RootsListChangedNotification {
  RootsListChangedNotification(meta: Option(Meta))
}

pub type SamplingMessage {
  SamplingMessage(content: MessageContent, role: Role)
}

pub type ServerCapabilities {
  ServerCapabilities(
    completions: Option(ServerCapabilitiesCompletions),
    logging: Option(ServerCapabilitiesLogging),
    prompts: Option(ServerCapabilitiesPrompts),
    resources: Option(ServerCapabilitiesResources),
    tools: Option(ServerCapabilitiesTools),
  )
}

pub type ServerCapabilitiesCompletions {
  ServerCapabilitiesCompletions
}

pub type ServerCapabilitiesLogging {
  ServerCapabilitiesLogging
}

pub type ServerCapabilitiesPrompts {
  ServerCapabilitiesPrompts(list_changed: Option(Bool))
}

pub type ServerCapabilitiesResources {
  ServerCapabilitiesResources(
    list_changed: Option(Bool),
    subscribe: Option(Bool),
  )
}

pub type ServerCapabilitiesTools {
  ServerCapabilitiesTools(list_changed: Option(Bool))
}

pub type SetLevelRequest {
  SetLevelRequest(level: LoggingLevel)
}

pub type SubscribeRequest {
  SubscribeRequest(uri: String)
}

pub type TextContent {
  TextContent(annotations: Option(Annotations), text: String, type_: String)
}

pub type TextResourceContents {
  TextResourceContents(mime_type: Option(String), text: String, uri: String)
}

pub type Tool {
  Tool(
    annotations: Option(ToolAnnotations),
    description: Option(String),
    input_schema: Dynamic,
    name: String,
  )
}

pub type ToolAnnotations {
  ToolAnnotations(
    destructive_hint: Option(Bool),
    idempotent_hint: Option(Bool),
    open_world_hint: Option(Bool),
    read_only_hint: Option(Bool),
    title: Option(String),
  )
}

pub type ToolListChangedNotification {
  ToolListChangedNotification(meta: Option(Meta))
}

pub type UnsubscribeRequest {
  UnsubscribeRequest(uri: String)
}

// JSON Encoders
pub fn initialize_result_to_json(r: InitializeResult) -> Json {
  let capabilities = []
  let capabilities = case r.capabilities.tools {
    Some(_) -> [#("tools", json.object([])), ..capabilities]
    None -> capabilities
  }
  let capabilities = case r.capabilities.resources {
    Some(_) -> [#("resources", json.object([])), ..capabilities]
    None -> capabilities
  }
  let capabilities = case r.capabilities.prompts {
    Some(_) -> [#("prompts", json.object([])), ..capabilities]
    None -> capabilities
  }
  let capabilities = case r.capabilities.logging {
    Some(_) -> [#("logging", json.object([])), ..capabilities]
    None -> capabilities
  }
  let fields = [
    #("protocolVersion", json.string(r.protocol_version)),
    #("capabilities", json.object(capabilities)),
    #(
      "serverInfo",
      json.object([
        #("name", json.string(r.server_info.name)),
        #("version", json.string(r.server_info.version)),
      ]),
    ),
  ]
  let fields = case r.instructions {
    Some(instructions) -> [
      #("instructions", json.string(instructions)),
      ..fields
    ]
    None -> fields
  }
  json.object(fields)
}

pub fn list_tools_result_to_json(r: ListToolsResult) -> Json {
  json.object([
    #("tools", json.array(r.tools, tool_to_json)),
  ])
}

fn tool_to_json(t: Tool) -> Json {
  let fields = [
    #("name", json.string(t.name)),
    #("inputSchema", t.input_schema |> unsafe_coerce),
  ]
  let fields = case t.description {
    Some(description) -> [#("description", json.string(description)), ..fields]
    None -> fields
  }
  let fields = case t.annotations {
    Some(annotations) -> [
      #("annotations", tool_annotations_to_json(annotations)),
      ..fields
    ]
    None -> fields
  }
  json.object(fields)
}

fn tool_annotations_to_json(annotations: ToolAnnotations) -> Json {
  let fields = []
  let fields = case annotations.title {
    Some(value) -> [#("title", json.string(value)), ..fields]
    None -> fields
  }
  let fields = case annotations.read_only_hint {
    Some(value) -> [#("readOnlyHint", json.bool(value)), ..fields]
    None -> fields
  }
  let fields = case annotations.destructive_hint {
    Some(value) -> [#("destructiveHint", json.bool(value)), ..fields]
    None -> fields
  }
  let fields = case annotations.idempotent_hint {
    Some(value) -> [#("idempotentHint", json.bool(value)), ..fields]
    None -> fields
  }
  let fields = case annotations.open_world_hint {
    Some(value) -> [#("openWorldHint", json.bool(value)), ..fields]
    None -> fields
  }
  json.object(fields)
}

pub fn call_tool_result_to_json(result: CallToolResult) -> Json {
  let fields = [
    #("content", json.array(result.content, tool_result_content_to_json)),
  ]
  let fields = case result.is_error {
    Some(is_error) -> [#("isError", json.bool(is_error)), ..fields]
    None -> fields
  }
  json.object(fields)
}

fn tool_result_content_to_json(content: ToolResultContent) -> Json {
  case content {
    TextToolContent(TextContent(_, text, type_)) ->
      json.object([
        #("type", json.string(type_)),
        #("text", json.string(text)),
      ])
    ImageToolContent(ImageContent(_, data, mime_type, type_)) ->
      json.object([
        #("type", json.string(type_)),
        #("data", json.string(data)),
        #("mimeType", json.string(mime_type)),
      ])
    AudioToolContent(AudioContent(_, data, mime_type, _)) ->
      json.object([
        #("type", json.string("audio")),
        #("data", json.string(data)),
        #("mimeType", json.string(mime_type)),
      ])
    ResourceToolContent(EmbeddedResource(_, resource, type_)) ->
      json.object([
        #("type", json.string(type_)),
        #("resource", resource_contents_to_json(resource)),
      ])
  }
}

fn resource_contents_to_json(contents: ResourceContents) -> Json {
  case contents {
    TextResource(TextResourceContents(mime_type, text, uri)) -> {
      let fields = [
        #("uri", json.string(uri)),
        #("text", json.string(text)),
      ]
      let fields = case mime_type {
        Some(value) -> [#("mimeType", json.string(value)), ..fields]
        None -> fields
      }
      json.object(fields)
    }
    BlobResource(BlobResourceContents(blob, mime_type, uri)) -> {
      let fields = [
        #("uri", json.string(uri)),
        #("blob", json.string(blob)),
      ]
      let fields = case mime_type {
        Some(value) -> [#("mimeType", json.string(value)), ..fields]
        None -> fields
      }
      json.object(fields)
    }
  }
}

// FFI
@external(erlang, "mcp_ffi", "is_binary")
fn is_binary(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "is_map")
fn is_map(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "get_map_value")
fn erl_get_map_value(m: Dynamic, k: String) -> Result(Dynamic, Nil)

@external(erlang, "mcp_ffi", "list_to_gleam")
fn unsafe_coerce(a: any) -> b

// Decoding helpers using FFI
fn dynamic_string(data: Dynamic) -> Result(String, List(DecodeError)) {
  case is_binary(data) {
    True -> Ok(unsafe_coerce(data))
    False ->
      Error([DecodeError(expected: "String", found: "wrong type", path: [])])
  }
}

pub fn decode_initialize_request(
  data: Dynamic,
) -> Result(InitializeRequest, List(DecodeError)) {
  case is_map(data) {
    True -> {
      case erl_get_map_value(data, "clientInfo") {
        Ok(client_info_val) -> {
          case decode_implementation(client_info_val) {
            Ok(client_info) -> {
              case get_map_string(data, "protocolVersion") {
                Ok(pv) -> {
                  Ok(InitializeRequest(
                    ClientCapabilities(None, None),
                    client_info,
                    pv,
                  ))
                }
                Error(e) -> Error(e)
              }
            }
            Error(e) -> Error(e)
          }
        }
        Error(_) ->
          Error([
            DecodeError(expected: "clientInfo", found: "missing", path: []),
          ])
      }
    }
    False ->
      Error([DecodeError(expected: "Map", found: "wrong type", path: [])])
  }
}

fn decode_implementation(
  data: Dynamic,
) -> Result(Implementation, List(DecodeError)) {
  case get_map_string(data, "name") {
    Ok(name) -> {
      case get_map_string(data, "version") {
        Ok(version) -> Ok(Implementation(name, version))
        Error(e) -> Error(e)
      }
    }
    Error(e) -> Error(e)
  }
}

fn get_map_string(m: Dynamic, k: String) -> Result(String, List(DecodeError)) {
  case erl_get_map_value(m, k) {
    Ok(v) -> dynamic_string(v)
    Error(_) ->
      Error([DecodeError(expected: "Key " <> k, found: "missing", path: [])])
  }
}
