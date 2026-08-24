import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import mcp_toolkit_gleam/core/protocol as mcp
import tools/arguments
import tools/hex_client

pub fn search_packages_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  use query <- result.try(arguments.query(req.arguments, "query"))
  use packages <- result.try(hex_client.search_packages(query))
  let packages = list.take(packages, 10)
  let text = case packages {
    [] -> "No Hex packages found for `" <> query <> "`."
    _ ->
      packages
      |> list.map(format_package)
      |> string.join("\n\n")
  }
  Ok(text_result(text))
}

pub fn get_package_releases_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  use package_name <- result.try(arguments.query(req.arguments, "package_name"))
  use _ <- result.try(validate_package_name(package_name))
  use releases <- result.try(hex_client.get_package_releases(package_name))
  let releases = list.take(releases, 20)
  let text = case releases {
    [] -> "No releases found for `" <> package_name <> "`."
    _ ->
      "### Releases for `"
      <> package_name
      <> "`\n"
      <> {
        releases
        |> list.map(fn(release) {
          let status = case release.retired {
            True -> " — retired"
            False -> ""
          }
          "- `" <> release.version <> "` — " <> release.inserted_at <> status
        })
        |> string.join("\n")
      }
  }
  Ok(text_result(text))
}

fn format_package(package: hex_client.HexPackage) -> String {
  let links =
    [
      link("Hex", Some(package.html_url)),
      link("Docs", package.docs_url),
      link("Repository", package.repository_url),
    ]
    |> list.filter_map(fn(item) {
      case item {
        Some(value) -> Ok(value)
        None -> Error(Nil)
      }
    })
    |> string.join(" · ")
  "### `"
  <> package.name
  <> "` "
  <> package.version
  <> "\n"
  <> package.description
  <> case links {
    "" -> ""
    _ -> "\n" <> links
  }
}

fn link(label: String, url: Option(String)) -> Option(String) {
  case url {
    Some("") | None -> None
    Some(url) -> Some("[" <> label <> "](" <> url <> ")")
  }
}

fn validate_package_name(package_name: String) -> Result(Nil, String) {
  let valid =
    package_name
    |> string.to_graphemes
    |> list.all(fn(character) {
      let lower = string.lowercase(character)
      character == lower
      && {
        case character {
          "_" -> True
          _ ->
            string.contains("abcdefghijklmnopqrstuvwxyz0123456789", character)
        }
      }
    })
  case valid {
    True -> Ok(Nil)
    False ->
      Error("'package_name' may contain only lowercase letters, digits, and _")
  }
}

fn text_result(text: String) -> mcp.CallToolResult {
  mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, text, "text"))],
    is_error: Some(False),
  )
}
