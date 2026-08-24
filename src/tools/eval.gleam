import filepath
import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp
import simplifile

@external(erlang, "cli_ffi", "exec")
fn exec(command: String) -> String

/// Evaluates a snippet of Gleam code by wrapping it in a main function (if missing),
/// creating a temporary project, running it, and returning the output.
pub fn evaluate_snippet(code: String) -> String {
  // We need a unique-ish ID. For now, just use gleam_eval_temp
  let project_dir = "/tmp/gleam_eval_temp"

  // 1. Clean up old eval dir if it exists
  let _ = exec("rm -rf " <> project_dir)

  // 2. Create scaffolding
  let _ = exec("mkdir -p " <> project_dir <> "/src")

  // 3. Write gleam.toml
  let toml =
    "name = \"eval_project\"\nversion = \"0.1.0\"\n\n[dependencies]\ngleam_stdlib = \">= 0.34.0 and < 2.0.0\"\n"
  let toml_path = filepath.join(project_dir, "gleam.toml")
  let _ = simplifile.write(toml_path, toml)

  // 4. Prepare code
  // If the user didn't provide a pub fn main(), wrap it for them so it runs directly.
  let final_code = case string.contains(code, "pub fn main") {
    True -> code
    False -> {
      let lines = string.split(code, "\n")
      let imports =
        lines
        |> list.filter(fn(l) { string.starts_with(string.trim(l), "import ") })
        |> string.join("\n")
      let body =
        lines
        |> list.filter(fn(l) {
          bool.negate(string.starts_with(string.trim(l), "import "))
        })
        |> string.join("\n")
      "import gleam/io\n"
      <> imports
      <> "\n\npub fn main() {\n  "
      <> body
      <> "\n}"
    }
  }

  // 5. Write src/eval_project.gleam
  let src_path = filepath.join(project_dir, "src/eval_project.gleam")
  let _ = simplifile.write(src_path, final_code)

  // 6. Run gleam project and capture output
  // We use 2>&1 to grab stdout and stderr, then we clean up the directory
  let output = exec("cd " <> project_dir <> " && gleam run 2>&1")

  // 7. Cleanup
  let _ = exec("rm -rf " <> project_dir)

  output
}

pub fn evaluate_snippet_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let code = case req.arguments {
    Some(args) -> get_string(args, "code", "")
    None -> ""
  }
  let output = evaluate_snippet(code)
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
