import filepath
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import mcp_toolkit_gleam/core/protocol as mcp
import simplifile
import tools/arguments
import tools/project

import gleam/dict
import tom

pub fn list_dependencies(project_path: String) -> Result(String, String) {
  use project_path <- result.try(project.validate(project_path))
  let toml_path = filepath.join(project_path, "gleam.toml")
  case simplifile.read(toml_path) {
    Ok(content) -> {
      case tom.parse(content) {
        Ok(doc) -> {
          let deps = case tom.get_table(doc, ["dependencies"]) {
            Ok(d) -> d
            Error(_) -> dict.new()
          }
          // Gleam accepts both spellings; `gleam new` writes the underscore
          // form since 1.x, older projects use the hyphen form.
          let dev_deps =
            dict.merge(
              table_or_empty(doc, "dev-dependencies"),
              table_or_empty(doc, "dev_dependencies"),
            )
          Ok(
            "### Project Dependencies\n"
            <> format_deps(deps)
            <> "\n### Dev Dependencies\n"
            <> format_deps(dev_deps),
          )
        }
        Error(_) -> Error("Could not parse TOML syntax in " <> toml_path)
      }
    }
    Error(_) -> Error("Could not read gleam.toml at " <> toml_path)
  }
}

fn table_or_empty(
  doc: dict.Dict(String, tom.Toml),
  key: String,
) -> dict.Dict(String, tom.Toml) {
  case tom.get_table(doc, [key]) {
    Ok(d) -> d
    Error(_) -> dict.new()
  }
}

fn format_deps(d: dict.Dict(String, tom.Toml)) -> String {
  let entries =
    d
    |> dict.to_list
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
  case entries {
    [] -> "No dependencies found.\n"
    _ ->
      string.join(
        list.map(entries, fn(pair) {
          let #(name, toml_val) = pair
          let val_str = case toml_val {
            tom.String(s) -> s
            tom.InlineTable(t) -> {
              let inner_entries =
                t
                |> dict.to_list
                |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
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

pub fn list_modules(project_path: String) -> Result(String, String) {
  use project_path <- result.try(project.validate(project_path))
  let search_path = filepath.join(project_path, "src")

  case simplifile.get_files(search_path) {
    Ok(files) -> {
      let prefix_length = string.length(search_path) + 1
      let modules =
        files
        |> list.filter(string.ends_with(_, ".gleam"))
        |> list.map(fn(path) {
          path
          |> string.drop_start(prefix_length)
          |> filepath.strip_extension
        })
        |> list.sort(string.compare)
      Ok(case modules {
        [] -> "No Gleam modules found in " <> search_path
        _ -> "### Local Modules\n" <> string.join(modules, "\n")
      })
    }
    Error(_) -> Error("Could not list files in " <> search_path)
  }
}

pub fn list_dependencies_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  use project_path <- result.try(arguments.optional_string(
    req.arguments,
    "project_path",
    ".",
  ))
  use output <- result.try(list_dependencies(project_path))
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}

pub fn list_local_modules_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  use project_path <- result.try(arguments.optional_string(
    req.arguments,
    "project_path",
    ".",
  ))
  use output <- result.try(list_modules(project_path))
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}
