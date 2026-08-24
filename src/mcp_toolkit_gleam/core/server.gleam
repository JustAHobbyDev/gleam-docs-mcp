import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/json
import gleam/list
import gleam/result
import mcp_toolkit_gleam/core/jsonrpc
import mcp_toolkit_gleam/core/jsonrpc_ser
import mcp_toolkit_gleam/core/method

import gleam/option.{type Option, None, Some}

import mcp_toolkit_gleam/core/protocol as mcp

pub type Builder {
  Builder(
    name: String,
    version: String,
    description: Option(String),
    instructions: Option(String),
    resources: Dict(String, ServerResource),
    resource_templates: Dict(String, ServerResourceTemplate),
    tools: Dict(String, ServerTool),
    prompts: Dict(String, ServerPrompt),
    capabilities: mcp.ServerCapabilities,
    page_limit: Option(Int),
  )
}

pub fn new(name name: String, version version: String) -> Builder {
  Builder(
    name:,
    version:,
    description: None,
    instructions: None,
    resources: dict.new(),
    resource_templates: dict.new(),
    tools: dict.new(),
    prompts: dict.new(),
    capabilities: mcp.ServerCapabilities(None, None, None, None, None),
    page_limit: None,
  )
}

pub fn description(builder: Builder, description: String) -> Builder {
  Builder(..builder, description: Some(description))
}

pub fn instructions(builder: Builder, instructions: String) -> Builder {
  Builder(..builder, instructions: Some(instructions))
}

pub fn add_resource(
  builder: Builder,
  resource: mcp.Resource,
  handler: fn(mcp.ReadResourceRequest) -> Result(mcp.ReadResourceResult, String),
) -> Builder {
  let capabilities = case builder.capabilities.resources {
    None ->
      mcp.ServerCapabilities(
        ..builder.capabilities,
        resources: Some(mcp.ServerCapabilitiesResources(
          Some(False),
          Some(False),
        )),
      )
    Some(_) -> builder.capabilities
  }

  Builder(
    ..builder,
    resources: dict.insert(
      builder.resources,
      resource.uri,
      ServerResource(resource, handler),
    ),
    capabilities:,
  )
}

pub fn add_resource_template(
  builder: Builder,
  template: mcp.ResourceTemplate,
  handler: fn(mcp.ReadResourceRequest) -> Result(mcp.ReadResourceResult, String),
) -> Builder {
  let capabilities = case builder.capabilities.resources {
    None ->
      mcp.ServerCapabilities(
        ..builder.capabilities,
        resources: Some(mcp.ServerCapabilitiesResources(
          Some(False),
          Some(False),
        )),
      )
    Some(_) -> builder.capabilities
  }

  Builder(
    ..builder,
    resource_templates: dict.insert(
      builder.resource_templates,
      template.name,
      ServerResourceTemplate(template, handler),
    ),
    capabilities:,
  )
}

pub fn add_tool(
  builder: Builder,
  tool: mcp.Tool,
  handler: fn(mcp.CallToolRequest(Dynamic)) ->
    Result(mcp.CallToolResult, String),
) -> Builder {
  let capabilities = case builder.capabilities.tools {
    None ->
      mcp.ServerCapabilities(
        ..builder.capabilities,
        tools: Some(mcp.ServerCapabilitiesTools(None)),
      )
    Some(_) -> builder.capabilities
  }
  Builder(
    ..builder,
    tools: dict.insert(
      builder.tools,
      tool.name,
      ServerTool(tool, fn(req) {
        handler(req) |> result.map_error(mcp.McpApplicationError)
      }),
    ),
    capabilities:,
  )
}

pub fn add_prompt(
  builder: Builder,
  prompt: mcp.Prompt,
  handler: fn(mcp.GetPromptRequest) -> Result(mcp.GetPromptResult, String),
) -> Builder {
  let capabilities = case builder.capabilities.prompts {
    None ->
      mcp.ServerCapabilities(
        ..builder.capabilities,
        prompts: Some(mcp.ServerCapabilitiesPrompts(None)),
      )
    Some(_) -> builder.capabilities
  }
  Builder(
    ..builder,
    prompts: dict.insert(
      builder.prompts,
      prompt.name,
      ServerPrompt(prompt, handler),
    ),
    capabilities:,
  )
}

pub fn resource_capabilities(
  builder: Builder,
  subscribe: Bool,
  list_changed: Bool,
) {
  let capabilities =
    mcp.ServerCapabilities(
      ..builder.capabilities,
      resources: Some(mcp.ServerCapabilitiesResources(
        Some(subscribe),
        Some(list_changed),
      )),
    )
  Builder(..builder, capabilities: capabilities)
}

pub fn prompt_capabilities(builder: Builder, list_changed: Bool) {
  let capabilities =
    mcp.ServerCapabilities(
      ..builder.capabilities,
      prompts: Some(mcp.ServerCapabilitiesPrompts(Some(list_changed))),
    )
  Builder(..builder, capabilities: capabilities)
}

pub fn tool_capabilities(builder: Builder, list_changed: Bool) {
  let capabilities =
    mcp.ServerCapabilities(
      ..builder.capabilities,
      tools: Some(mcp.ServerCapabilitiesTools(Some(list_changed))),
    )
  Builder(..builder, capabilities: capabilities)
}

pub fn enable_logging(builder: Builder) {
  let capabilities =
    mcp.ServerCapabilities(
      ..builder.capabilities,
      logging: Some(mcp.ServerCapabilitiesLogging),
    )
  Builder(..builder, capabilities: capabilities)
}

pub fn page_limit(builder: Builder, page_limit: Int) -> Builder {
  Builder(..builder, page_limit: Some(page_limit))
}

pub opaque type Server {
  Server(
    name: String,
    version: String,
    description: Option(String),
    instructions: Option(String),
    resources: Dict(String, ServerResource),
    resource_templates: Dict(String, ServerResourceTemplate),
    tools: Dict(String, ServerTool),
    prompts: Dict(String, ServerPrompt),
    capabilities: mcp.ServerCapabilities,
    page_limit: Option(Int),
  )
}

pub fn build(builder: Builder) -> Server {
  Server(
    name: builder.name,
    version: builder.version,
    description: builder.description,
    instructions: builder.instructions,
    resources: builder.resources,
    resource_templates: builder.resource_templates,
    tools: builder.tools,
    prompts: builder.prompts,
    capabilities: builder.capabilities,
    page_limit: builder.page_limit,
  )
}

pub type ServerPrompt {
  ServerPrompt(
    prompt: mcp.Prompt,
    handler: fn(mcp.GetPromptRequest) -> Result(mcp.GetPromptResult, String),
  )
}

pub type ServerResource {
  ServerResource(
    resource: mcp.Resource,
    handler: fn(mcp.ReadResourceRequest) ->
      Result(mcp.ReadResourceResult, String),
  )
}

pub type ServerResourceTemplate {
  ServerResourceTemplate(
    template: mcp.ResourceTemplate,
    handler: fn(mcp.ReadResourceRequest) ->
      Result(mcp.ReadResourceResult, String),
  )
}

pub type ServerTool {
  ServerTool(
    tool: mcp.Tool,
    handler: fn(mcp.CallToolRequest(Dynamic)) ->
      Result(mcp.CallToolResult, mcp.McpError),
  )
}

import gleam/dynamic/decode

pub fn handle_message(
  server: Server,
  message: String,
) -> Result(Option(json.Json), json.Json) {
  case json.parse(message, decode.dynamic) {
    Ok(msg_dyn) -> {
      case jsonrpc.decode_message(msg_dyn) {
        Ok(msg) -> {
          case msg {
            jsonrpc.Request(id, m, params) -> {
              handle_request(server, id, m, params) |> result.map(Some)
            }
            jsonrpc.Notification(m, params) -> {
              let _ = handle_notification(server, m, params)
              Ok(None)
            }
            _ -> Ok(None)
          }
        }
        Error(_) -> {
          Error(json.object([#("error", json.string("Invalid request"))]))
        }
      }
    }
    Error(_) -> {
      Error(json.object([#("error", json.string("Parse error"))]))
    }
  }
}

fn handle_request(
  server: Server,
  id: jsonrpc.Id,
  method_name: String,
  params: Dynamic,
) -> Result(json.Json, json.Json) {
  case method_name {
    m if m == method.initialize -> {
      case mcp.decode_initialize_request(params) {
        Ok(req) -> {
          initialize(server, req)
          |> result.map(mcp.initialize_result_to_json)
          |> result.map(jsonrpc_ser.response(_, id))
          |> result.map_error(fn(err_json) {
            jsonrpc_ser.error_response(
              -32_603,
              "Internal error",
              Some(err_json),
              id,
            )
          })
        }
        Error(_) -> {
          Error(jsonrpc_ser.error_response(-32_602, "Invalid params", None, id))
        }
      }
    }

    m if m == method.ping -> {
      Ok(jsonrpc_ser.response(json.object([]), id))
    }

    m if m == method.tools_list -> {
      list_tools(server, mcp.ListRequest(None))
      |> result.map(mcp.list_tools_result_to_json)
      |> result.map(jsonrpc_ser.response(_, id))
      |> result.map_error(fn(_) {
        jsonrpc_ser.error_response(-32_603, "Internal error", None, id)
      })
    }

    m if m == method.tools_call -> {
      case mcp.decode_call_tool_request(params) {
        Ok(request) ->
          case call_tool(server, request) {
            Ok(response) ->
              Ok(
                response
                |> mcp.call_tool_result_to_json
                |> jsonrpc_ser.response(id),
              )
            Error(mcp.McpApplicationError(message)) ->
              Error(jsonrpc_ser.error_response(-32_602, message, None, id))
            Error(_) ->
              Error(jsonrpc_ser.error_response(
                -32_603,
                "Tool execution failed",
                None,
                id,
              ))
          }
        Error(_) ->
          Error(jsonrpc_ser.error_response(-32_602, "Invalid params", None, id))
      }
    }

    _ -> {
      Error(jsonrpc_ser.error_response(-32_601, "Method not found", None, id))
    }
  }
}

fn handle_notification(
  _server: Server,
  _method_name: String,
  _params: Dynamic,
) -> Nil {
  Nil
}

pub fn initialize(
  server: Server,
  _request: mcp.InitializeRequest,
) -> Result(mcp.InitializeResult, json.Json) {
  Ok(mcp.InitializeResult(
    capabilities: server.capabilities,
    protocol_version: mcp.protocol_version,
    server_info: mcp.Implementation(server.name, server.version),
    instructions: server.instructions,
    meta: None,
  ))
}

pub fn list_tools(
  server: Server,
  _request: mcp.ListRequest,
) -> Result(mcp.ListToolsResult, json.Json) {
  let tools =
    dict.values(server.tools)
    |> list.map(fn(t) { t.tool })
  Ok(mcp.ListToolsResult(tools:, next_cursor: None, meta: None))
}

pub fn call_tool(
  server: Server,
  request: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, mcp.McpError) {
  case dict.get(server.tools, request.name) {
    Ok(tool) ->
      case tool.handler(request) {
        Ok(result) -> Ok(result)
        Error(mcp.McpApplicationError(message)) ->
          Ok(mcp.CallToolResult(
            meta: None,
            content: [
              mcp.TextToolContent(mcp.TextContent(None, message, "text")),
            ],
            is_error: Some(True),
          ))
        Error(error) -> Error(error)
      }
    Error(_) ->
      Error(mcp.McpApplicationError("Tool not found: " <> request.name))
  }
}
