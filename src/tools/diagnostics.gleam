import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import mcp_toolkit_gleam/core/protocol as mcp
import tools/arguments
import tools/command
import tools/project

pub fn get_compiler_diagnostics(
  project_path: String,
) -> Result(String, String) {
  use project_path <- result.try(project.validate(project_path))
  use checked <- result.try(command.run(
    "gleam",
    ["check"],
    project_path,
    60_000,
    65_536,
  ))
  let command.CommandResult(exit_code, output, truncated) = checked
  let output = case string.trim(output) {
    "" if exit_code == 0 -> "Project type-checks successfully."
    _ -> output
  }
  let suffix = case truncated {
    True -> "\n\n[Output truncated at 64 KiB]"
    False -> ""
  }
  Ok(
    "gleam check exited with code "
    <> int.to_string(exit_code)
    <> "\n\n"
    <> output
    <> suffix,
  )
}

pub fn get_compiler_diagnostics_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  use project_path <- result.try(arguments.optional_string(
    req.arguments,
    "project_path",
    ".",
  ))
  use output <- result.try(get_compiler_diagnostics(project_path))
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}
