import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit
import mcp_toolkit_gleam/core/server
import native_docs_mcp

pub fn main() -> Nil {
  gleeunit.main()
}

fn request(message: String) -> String {
  let assert Ok(Some(response)) =
    native_docs_mcp.build_server()
    |> server.handle_message(message)
  json.to_string(response)
}

pub fn initialize_advertises_only_tools_test() {
  let response =
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}",
    )

  assert string.contains(response, "\"tools\":{}")
  assert !string.contains(response, "\"resources\":{}")
  assert string.contains(response, "\"name\":\"gleam-docs-mcp\"")
  assert string.contains(response, "\"version\":\"1.0.0\"")
}

pub fn list_tools_is_safe_core_test() {
  let response =
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}",
    )

  let names = [
    "get_compiler_diagnostics",
    "list_dependencies",
    "list_local_modules",
    "gloogle_search",
    "search_hex_packages",
    "get_package_releases",
  ]
  assert list.all(names, string.contains(response, _))
  assert !string.contains(response, "format_project")
  assert !string.contains(response, "evaluate_snippet")
  assert !string.contains(response, "search_functions")
  assert string.contains(response, "\"readOnlyHint\":true")
  assert string.contains(response, "\"destructiveHint\":false")
  assert string.contains(response, "\"openWorldHint\":true")
  assert string.contains(response, "\"openWorldHint\":false")
  assert string.contains(response, "\"inputSchema\":{\"type\":\"object\"")
}

pub fn local_tool_dispatches_test() {
  let response =
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"list_dependencies\",\"arguments\":{\"project_path\":\".\"}}}",
    )

  assert string.contains(response, "Project Dependencies")
  assert string.contains(response, "\"type\":\"text\"")
  assert string.contains(response, "\"isError\":false")
}

pub fn invalid_tool_arguments_are_tool_error_test() {
  let response =
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"get_package_releases\",\"arguments\":{}}}",
    )

  assert string.contains(response, "\"isError\":true")
  assert string.contains(response, "Expected 'package_name' to be a string")
}

pub fn unknown_tool_is_invalid_params_test() {
  let assert Error(response) =
    native_docs_mcp.build_server()
    |> server.handle_message(
      "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"missing\",\"arguments\":{}}}",
    )
  let response = json.to_string(response)

  assert string.contains(response, "\"code\":-32602")
  assert string.contains(response, "Tool not found: missing")
}
