import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import mcp_toolkit_gleam/core/protocol as mcp
import tools/arguments

const api_url = "https://api.gloogle.run/search"

type SearchEnvelope {
  SearchEnvelope(
    exact_type_matches: List(SearchResult),
    exact_matches: List(SearchResult),
    matches: List(SearchResult),
    searches: List(SearchResult),
    docs_searches: List(SearchResult),
    module_searches: List(SearchResult),
  )
}

type SearchResult {
  SearchResult(
    type_name: String,
    documentation: String,
    signature: Signature,
    module_name: String,
    package_name: String,
    version: String,
  )
}

type Signature {
  FunctionSignature(name: String, parameters: List(Parameter), return: Type)
  ConstantSignature(type_: Type)
  TypeAliasSignature(parameters: Int, alias: Type)
  TypeDefinitionSignature(parameters: Int, constructors: List(Constructor))
}

type Parameter {
  Parameter(label: Option(String), type_: Type)
}

type Constructor {
  Constructor(name: String, parameters: List(Parameter))
}

type Type {
  Variable(Int)
  FunctionType(parameters: List(Type), return: Type)
  TupleType(elements: List(Type))
  NamedType(name: String, parameters: List(Type))
}

pub fn gloogle_search(query: String) -> Result(String, String) {
  use req <- result.try(
    request.to(api_url)
    |> result.map_error(fn(_) { "Could not construct Gloogle request" }),
  )
  let req =
    req
    |> request.set_query([#("q", query)])
    |> request.set_header("user-agent", "gleam-docs-mcp/1.0.0")
  use response <- result.try(
    httpc.configure()
    |> httpc.timeout(10_000)
    |> httpc.follow_redirects(True)
    |> httpc.dispatch(req)
    |> result.map_error(fn(error) {
      "Gloogle is unavailable: " <> string.inspect(error)
    }),
  )
  use <- status_ok(response.status)
  decode_search_response(response.body, query)
}

pub fn decode_search_response(
  body: String,
  query: String,
) -> Result(String, String) {
  use envelope <- result.try(
    json.parse(body, search_envelope_decoder())
    |> result.map_error(fn(_) { "Gloogle returned an unexpected response" }),
  )
  let results =
    [
      envelope.exact_type_matches,
      envelope.exact_matches,
      envelope.matches,
      envelope.searches,
      envelope.docs_searches,
      envelope.module_searches,
    ]
    |> list.flatten
    |> list.unique
    |> list.take(10)
  Ok(case results {
    [] -> "No Gloogle results found for `" <> query <> "`."
    _ -> results |> list.map(format_search_result) |> string.join("\n\n---\n\n")
  })
}

pub fn gloogle_search_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  use query <- result.try(arguments.query(req.arguments, "query"))
  use output <- result.try(gloogle_search(query))
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}

fn status_ok(
  status: Int,
  next: fn() -> Result(a, String),
) -> Result(a, String) {
  case status {
    200 -> next()
    code -> Error("Gloogle returned HTTP " <> int.to_string(code))
  }
}

fn search_envelope_decoder() {
  let results = decode.list(search_result_decoder())
  use exact_type_matches <- decode.field("exact-type-matches", results)
  use exact_matches <- decode.field("exact-matches", results)
  use matches <- decode.field("matches", results)
  use searches <- decode.field("searches", results)
  use docs_searches <- decode.field("docs-searches", results)
  use module_searches <- decode.field("module-searches", results)
  decode.success(SearchEnvelope(
    exact_type_matches:,
    exact_matches:,
    matches:,
    searches:,
    docs_searches:,
    module_searches:,
  ))
}

fn search_result_decoder() {
  use type_name <- decode.field("type_name", decode.string)
  use documentation <- decode.optional_field("documentation", "", decode.string)
  use signature <- decode.field("json_signature", signature_decoder())
  use module_name <- decode.field("module_name", decode.string)
  use package_name <- decode.field("package_name", decode.string)
  use version <- decode.field("version", decode.string)
  decode.success(SearchResult(
    type_name:,
    documentation:,
    signature:,
    module_name:,
    package_name:,
    version:,
  ))
}

fn signature_decoder() {
  use kind <- decode.field("kind", decode.string)
  case kind {
    "function" -> {
      use name <- decode.field("name", decode.string)
      use return <- decode.field("return", type_decoder())
      use parameters <- decode.field(
        "parameters",
        decode.list(parameter_decoder()),
      )
      decode.success(FunctionSignature(name:, parameters:, return:))
    }
    "constant" -> {
      use type_ <- decode.field("type", type_decoder())
      decode.success(ConstantSignature(type_:))
    }
    "type-alias" -> {
      use parameters <- decode.field("parameters", decode.int)
      use alias <- decode.field("alias", type_decoder())
      decode.success(TypeAliasSignature(parameters:, alias:))
    }
    "type-definition" -> {
      use parameters <- decode.field("parameters", decode.int)
      use constructors <- decode.field(
        "constructors",
        decode.list(constructor_decoder()),
      )
      decode.success(TypeDefinitionSignature(parameters:, constructors:))
    }
    _ -> decode.failure(ConstantSignature(Variable(0)), "Gloogle signature")
  }
}

fn parameter_decoder() {
  use label <- decode.optional_field(
    "label",
    None,
    decode.optional(decode.string),
  )
  use type_ <- decode.field("type", type_decoder())
  decode.success(Parameter(label:, type_:))
}

fn constructor_decoder() {
  use name <- decode.field("name", decode.string)
  use parameters <- decode.field("parameters", decode.list(parameter_decoder()))
  decode.success(Constructor(name:, parameters:))
}

fn type_decoder() {
  use kind <- decode.field("kind", decode.string)
  case kind {
    "variable" -> {
      use id <- decode.field("id", decode.int)
      decode.success(Variable(id))
    }
    "fn" -> {
      use parameters <- decode.field("params", decode.list(type_decoder()))
      use return <- decode.field("return", type_decoder())
      decode.success(FunctionType(parameters:, return:))
    }
    "tuple" -> {
      use elements <- decode.field("elements", decode.list(type_decoder()))
      decode.success(TupleType(elements:))
    }
    "named" -> {
      use name <- decode.field("name", decode.string)
      use parameters <- decode.field("parameters", decode.list(type_decoder()))
      decode.success(NamedType(name:, parameters:))
    }
    _ -> decode.failure(Variable(0), "Gloogle type")
  }
}

fn format_search_result(item: SearchResult) -> String {
  let docs = case string.trim(item.documentation) {
    "" -> "No documentation provided."
    documentation -> truncate(documentation, 500)
  }
  let url =
    "https://hexdocs.pm/"
    <> item.package_name
    <> "/"
    <> item.version
    <> "/"
    <> item.module_name
    <> ".html#"
    <> item.type_name
  "### `"
  <> item.package_name
  <> "@"
  <> item.version
  <> "` — `"
  <> item.module_name
  <> "."
  <> item.type_name
  <> "`\n\n```gleam\n"
  <> format_signature(item.signature, item.type_name)
  <> "\n```\n\n"
  <> docs
  <> "\n\n[HexDocs]("
  <> url
  <> ")"
}

fn format_signature(signature: Signature, type_name: String) -> String {
  case signature {
    FunctionSignature(name, parameters, return) ->
      "fn "
      <> name
      <> "("
      <> { parameters |> list.map(format_parameter) |> string.join(", ") }
      <> ") -> "
      <> format_type(return)
    ConstantSignature(type_) ->
      "const " <> type_name <> ": " <> format_type(type_)
    TypeAliasSignature(parameters, alias) ->
      "type "
      <> type_name
      <> format_type_parameters(parameters)
      <> " = "
      <> format_type(alias)
    TypeDefinitionSignature(parameters, constructors) ->
      "type "
      <> type_name
      <> format_type_parameters(parameters)
      <> case constructors {
        [] -> ""
        _ ->
          " {\n  "
          <> {
            constructors |> list.map(format_constructor) |> string.join("\n  ")
          }
          <> "\n}"
      }
  }
}

fn format_parameter(parameter: Parameter) -> String {
  let Parameter(label, type_) = parameter
  case label {
    Some(label) -> label <> ": " <> format_type(type_)
    None -> format_type(type_)
  }
}

fn format_constructor(constructor: Constructor) -> String {
  let Constructor(name, parameters) = constructor
  case parameters {
    [] -> name
    _ ->
      name
      <> "("
      <> { parameters |> list.map(format_parameter) |> string.join(", ") }
      <> ")"
  }
}

fn format_type(type_: Type) -> String {
  case type_ {
    Variable(id) -> "t" <> int.to_string(id)
    FunctionType(parameters, return) ->
      "fn("
      <> { parameters |> list.map(format_type) |> string.join(", ") }
      <> ") -> "
      <> format_type(return)
    TupleType(elements) ->
      "#(" <> { elements |> list.map(format_type) |> string.join(", ") } <> ")"
    NamedType(name, parameters) ->
      name
      <> case parameters {
        [] -> ""
        _ ->
          "("
          <> { parameters |> list.map(format_type) |> string.join(", ") }
          <> ")"
      }
  }
}

fn format_type_parameters(count: Int) -> String {
  case count {
    0 -> ""
    _ ->
      "("
      <> {
        type_parameter_names(count, 0, [])
        |> string.join(", ")
      }
      <> ")"
  }
}

fn type_parameter_names(count: Int, index: Int, names: List(String)) {
  case index >= count {
    True -> list.reverse(names)
    False ->
      type_parameter_names(count, index + 1, [
        "t" <> int.to_string(index),
        ..names
      ])
  }
}

fn truncate(value: String, limit: Int) -> String {
  case string.length(value) > limit {
    True -> string.slice(value, at_index: 0, length: limit) <> "…"
    False -> value
  }
}
