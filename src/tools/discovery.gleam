import filepath
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp
import simplifile

import gleam/dict
import tom

pub fn list_dependencies(project_path: String) -> String {
  let toml_path = filepath.join(project_path, "gleam.toml")
  case simplifile.read(toml_path) {
    Ok(content) -> {
      case tom.parse(content) {
        Ok(doc) -> {
          let deps = case tom.get_table(doc, ["dependencies"]) {
            Ok(d) -> d
            Error(_) -> dict.new()
          }
          let dev_deps = case tom.get_table(doc, ["dev-dependencies"]) {
            Ok(d) -> d
            Error(_) -> dict.new()
          }
          "### Project Dependencies\n"
          <> format_deps(deps)
          <> "\n### Dev Dependencies\n"
          <> format_deps(dev_deps)
        }
        Error(_) -> "Error: Could not parse TOML syntax in " <> toml_path
      }
    }
    Error(_) -> "Error: Could not read gleam.toml at " <> toml_path
  }
}

fn format_deps(d: dict.Dict(String, tom.Toml)) -> String {
  let entries = dict.to_list(d)
  case entries {
    [] -> "No dependencies found.\n"
    _ ->
      string.join(
        list.map(entries, fn(pair) {
          let #(name, toml_val) = pair
          let val_str = case toml_val {
            tom.String(s) -> s
            tom.InlineTable(t) -> {
              let inner_entries = dict.to_list(t)
              "{"
              <> string.join(
                list.map(inner_entries, fn(ip) {
                  let #(k, v) = ip
                  let v_str = case v {
                    tom.String(s) -> "\"" <> s <> "\""
                    _ -> "..."
                  }
                  k <> " = " <> v_str
                }),
                ", ",
              )
              <> "}"
            }
            _ -> "..."
          }
          "- **" <> name <> "**: " <> val_str
        }),
        "\n",
      )
  }
}

pub fn list_modules(
  project_path: String,
  package_name: Option(String),
) -> String {
  let relative_src = case package_name {
    Some(pkg) -> filepath.join("build/packages", pkg) |> filepath.join("src")
    None -> "src"
  }
  let search_path = filepath.join(project_path, relative_src)

  case simplifile.get_files(search_path) {
    Ok(files) -> {
      "### Modules in " <> search_path <> "\n" <> string.join(files, "\n")
    }
    Error(_) -> "Error: Could not list files in " <> search_path
  }
}

pub fn list_dependencies_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let project_path = case req.arguments {
    Some(args) -> get_string(args, "project_path", ".")
    None -> "."
  }
  let output = list_dependencies(project_path)
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}

pub fn list_local_modules_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let project_path = case req.arguments {
    Some(args) -> get_string(args, "project_path", ".")
    None -> "."
  }
  let output = list_modules(project_path, None)
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
