import gleam/json
import gleam/option.{Some}
import gleam/string
import gleeunit
import mcp_toolkit_gleam/core/server
import native_docs_mcp

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
fn request(message: String) -> String {
  let assert Ok(Some(response)) =
    native_docs_mcp.build_server()
    |> server.handle_message(message)
  json.to_string(response)
}

pub fn initialize_advertises_tools_test() {
  let response =
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}",
    )

  assert string.contains(response, "\"tools\":{}")
  assert string.contains(response, "\"serverInfo\"")
}

pub fn list_tools_has_json_schemas_test() {
  let response =
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}",
    )

  assert string.contains(response, "\"get_compiler_diagnostics\"")
  assert string.contains(response, "\"inputSchema\":{\"type\":\"object\"")
  assert !string.contains(response, "\"inputSchema\":null")
}

pub fn call_tool_dispatches_and_encodes_result_test() {
  let response =
    request(
      "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"search_functions\",\"arguments\":{\"package_name\":\"gleam_stdlib\",\"query\":\"map\"}}}",
    )

  assert string.contains(response, "\"type\":\"text\"")
  assert string.contains(
    response,
    "\"text\":\"Searching functions in gleam_stdlib for: map\"",
  )
  assert string.contains(response, "\"isError\":false")
}

pub fn unknown_tool_is_invalid_params_test() {
  let assert Error(response) =
    native_docs_mcp.build_server()
    |> server.handle_message(
      "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"missing\",\"arguments\":{}}}",
    )
  let response = json.to_string(response)

  assert string.contains(response, "\"code\":-32602")
  assert string.contains(response, "Tool not found: missing")
}
