import filepath
import gleam/dynamic.{type Dynamic}
import gleam/option.{None, Some}
import gleam/string
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp
import simplifile

pub fn get_symbol_context(
  project_path: String,
  module_name: String,
  symbol_name: String,
) -> String {
  let module_file = string.replace(module_name, "/", "_") <> ".gleam"
  let src_path =
    filepath.join(project_path, "src") |> filepath.join(module_file)

  case simplifile.read(src_path) {
    Ok(content) -> {
      // Very simple greedy search for now
      case string.contains(content, "pub fn " <> symbol_name) {
        True ->
          "### Symbol Context: "
          <> module_name
          <> "."
          <> symbol_name
          <> "\n(Source found in "
          <> src_path
          <> ")"
        False -> "Symbol '" <> symbol_name <> "' not found in " <> src_path
      }
    }
    Error(_) -> "Error: Could not find module file at " <> src_path
  }
}

pub fn get_remote_symbol(
  package_name: String,
  module: String,
  symbol: String,
) -> String {
  let url =
    "https://hexdocs.pm/" <> package_name <> "/" <> module <> ".html#" <> symbol
  "Remote URL: " <> url
}

pub fn get_symbol_context_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let project_path = case req.arguments {
    Some(args) -> get_string(args, "project_path", ".")
    None -> "."
  }
  let module_name = case req.arguments {
    Some(args) -> get_string(args, "module_name", "")
    None -> ""
  }
  let symbol_name = case req.arguments {
    Some(args) -> get_string(args, "symbol_name", "")
    None -> ""
  }
  let output = get_symbol_context(project_path, module_name, symbol_name)
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
