import gleam/dict
import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

const api_url = "https://hex.pm/api"

pub type HexPackage {
  HexPackage(
    name: String,
    version: String,
    description: String,
    docs_url: Option(String),
    html_url: String,
    repository_url: Option(String),
  )
}

pub type HexRelease {
  HexRelease(version: String, inserted_at: String, retired: Bool)
}

type HexMeta {
  HexMeta(description: String, repository_url: Option(String))
}

pub fn search_packages(query: String) -> Result(List(HexPackage), String) {
  use req <- result.try(
    request.to(api_url <> "/packages")
    |> result.map_error(fn(_) { "Could not construct Hex API request" }),
  )
  let req =
    req
    |> request.set_query([#("search", query)])
    |> request.set_header("user-agent", "gleam-docs-mcp/1.0.0")
  use body <- result.try(fetch(req))
  decode_package_search(body)
}

pub fn get_package_releases(
  package_name: String,
) -> Result(List(HexRelease), String) {
  use req <- result.try(
    request.to(api_url <> "/packages/" <> package_name)
    |> result.map_error(fn(_) { "Could not construct Hex API request" }),
  )
  let req = request.set_header(req, "user-agent", "gleam-docs-mcp/1.0.0")
  use body <- result.try(fetch(req))
  decode_releases(body)
}

pub fn decode_package_search(body: String) -> Result(List(HexPackage), String) {
  json.parse(body, decode.list(package_decoder()))
  |> result.map_error(fn(_) { "Hex returned an unexpected package response" })
}

pub fn decode_releases(body: String) -> Result(List(HexRelease), String) {
  let decoder = {
    use releases <- decode.field("releases", decode.list(release_decoder()))
    decode.success(releases)
  }
  json.parse(body, decoder)
  |> result.map_error(fn(_) { "Hex returned an unexpected releases response" })
}

fn fetch(req) -> Result(String, String) {
  use response <- result.try(
    httpc.configure()
    |> httpc.timeout(10_000)
    |> httpc.follow_redirects(True)
    |> httpc.dispatch(req)
    |> result.map_error(fn(error) {
      "Could not reach Hex: " <> string.inspect(error)
    }),
  )
  case response.status {
    200 -> Ok(response.body)
    404 -> Error("Hex package was not found")
    status -> Error("Hex returned HTTP " <> int.to_string(status))
  }
}

fn package_decoder() {
  use name <- decode.field("name", decode.string)
  use version <- decode.optional_field(
    "latest_version",
    "unknown",
    decode.string,
  )
  use meta <- decode.optional_field("meta", HexMeta("", None), meta_decoder())
  use docs_url <- decode.optional_field(
    "docs_html_url",
    None,
    decode.optional(decode.string),
  )
  use html_url <- decode.optional_field("html_url", "", decode.string)
  decode.success(HexPackage(
    name:,
    version:,
    description: meta.description,
    docs_url:,
    html_url:,
    repository_url: meta.repository_url,
  ))
}

fn meta_decoder() {
  use description <- decode.optional_field("description", "", decode.string)
  use links <- decode.optional_field(
    "links",
    dict.new(),
    decode.dict(decode.string, decode.string),
  )
  let repository_url = case dict.get(links, "Repository") {
    Ok(url) -> Some(url)
    Error(_) -> None
  }
  decode.success(HexMeta(description:, repository_url:))
}

fn release_decoder() {
  use version <- decode.field("version", decode.string)
  use inserted_at <- decode.optional_field(
    "inserted_at",
    "unknown",
    decode.string,
  )
  use retirement <- decode.optional_field(
    "retirement",
    None,
    decode.optional(decode.dynamic),
  )
  decode.success(HexRelease(
    version:,
    inserted_at:,
    retired: option.is_some(retirement),
  ))
}
