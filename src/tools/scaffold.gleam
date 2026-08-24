import filepath
import gleam/dynamic.{type Dynamic}
import gleam/option.{None, Some}
import gleam/string
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp
import simplifile

pub fn scaffold_module(
  project_path: String,
  module_name: String,
  content: String,
) -> String {
  // Convert module name like foo/bar/baz to a clean path
  let relative_module_path = module_name <> ".gleam"
  let full_file_path =
    filepath.join(filepath.join(project_path, "src"), relative_module_path)

  let parent_dir = filepath.directory_name(full_file_path)

  // Safe recursive creation via simplifile (derived from gleam-lang/cookbook)
  let _ = simplifile.create_directory_all(parent_dir)

  case simplifile.is_file(full_file_path) {
    Ok(True) ->
      "Error: Module " <> module_name <> " already exists at " <> full_file_path
    _ -> {
      case simplifile.write(to: full_file_path, contents: content) {
        Ok(_) ->
          "Successfully scaffolded module "
          <> module_name
          <> " at "
          <> full_file_path
        Error(_) -> "Error: Could not write file " <> full_file_path
      }
    }
  }
}

pub fn scaffold_module_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let project_path = case req.arguments {
    Some(args) -> get_string(args, "project_path", ".")
    None -> "."
  }
  let module_name = case req.arguments {
    Some(args) -> get_string(args, "module_name", "new_module")
    None -> "new_module"
  }
  let content = case req.arguments {
    Some(args) -> get_string(args, "content", "pub fn main() { Nil }")
    None -> "pub fn main() { Nil }"
  }

  let output = scaffold_module(project_path, module_name, content)
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(string.starts_with(output, "Error")),
  ))
}

fn get_string(dyn: Dynamic, key: String, default: String) -> String {
  case mcp_ffi.erl_get_map_value(dyn, key) {
    Ok(v) -> mcp_ffi.unsafe_coerce(v)
    Error(_) -> default
  }
}
