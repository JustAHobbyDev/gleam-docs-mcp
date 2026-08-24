import gleam/dynamic.{type Dynamic}
import gleam/option.{None, Some}
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp

@external(erlang, "cli_ffi", "exec")
pub fn exec(command: String) -> String

pub fn get_compiler_diagnostics(project_path: String) -> String {
  // We'll run 'gleam check' and capture output
  exec("cd " <> project_path <> " && gleam check 2>&1")
}

pub fn format_project(project_path: String) -> String {
  exec("cd " <> project_path <> " && gleam format")
}

pub fn get_compiler_diagnostics_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let project_path = case req.arguments {
    Some(args) -> get_string(args, "project_path", ".")
    None -> "."
  }
  let output = get_compiler_diagnostics(project_path)
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}

pub fn format_project_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let project_path = case req.arguments {
    Some(args) -> get_string(args, "project_path", ".")
    None -> "."
  }
  let output = format_project(project_path)
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}

fn get_string(dyn: Dynamic, key: String, default: String) -> String {
  case mcp_ffi.erl_get_map_value(dyn, key) {
    Ok(v) -> mcp_ffi.unsafe_coerce(v)
    Error(_) -> default
  }
}
