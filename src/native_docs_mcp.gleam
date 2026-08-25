import gleam/io
import gleam/json
import gleam/option.{None, Some}
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp
import mcp_toolkit_gleam/core/server
import tools/dependency_api
import tools/diagnostics
import tools/discovery
import tools/global
import tools/hex

@external(erlang, "mcp_ffi", "read_line")
fn erl_read_line() -> Result(String, Nil)

pub fn main() {
  build_server()
  |> loop
}

pub fn build_server() -> server.Server {
  server.new("gleam-docs-mcp", "1.0.0")
  |> server.description(
    "Grounded Gleam compiler diagnostics and ecosystem package discovery",
  )
  |> server.instructions(
    "Use local-project tools only with paths supplied by the user. External search tools are stateless and may report service availability errors.",
  )
  |> server.add_tool(
    mcp.Tool(
      name: "get_compiler_diagnostics",
      description: Some(
        "Run gleam check in a local project and return its diagnostics",
      ),
      input_schema: project_schema(),
      annotations: Some(read_only_annotations("Get compiler diagnostics", False)),
    ),
    diagnostics.get_compiler_diagnostics_handler,
  )
  |> server.add_tool(
    mcp.Tool(
      name: "list_dependencies",
      description: Some(
        "Read dependency and dev-dependency declarations from gleam.toml",
      ),
      input_schema: project_schema(),
      annotations: Some(read_only_annotations(
        "List project dependencies",
        False,
      )),
    ),
    discovery.list_dependencies_handler,
  )
  |> server.add_tool(
    mcp.Tool(
      name: "list_local_modules",
      description: Some("List Gleam modules under a local project's src tree"),
      input_schema: project_schema(),
      annotations: Some(read_only_annotations("List local modules", False)),
    ),
    discovery.list_local_modules_handler,
  )
  |> server.add_tool(
    mcp.Tool(
      name: "get_dependency_api",
      description: Some(
        "Read the public API (pub fn/type/const signatures and doc comments) of a module in a dependency already fetched under build/packages, or list the dependency's modules when no module is given. Never fetches.",
      ),
      input_schema: object_schema(
        [
          string_property(
            "project_path",
            "Path to the Gleam project; defaults to the server working directory",
          ),
          string_property(
            "dependency",
            "Package name as it appears in manifest.toml, e.g. mist",
          ),
          string_property(
            "module",
            "Module name within the package, e.g. gleam/http/request; omit to list modules",
          ),
        ],
        ["dependency"],
      ),
      annotations: Some(read_only_annotations("Get dependency API", False)),
    ),
    dependency_api.get_dependency_api_handler,
  )
  |> server.add_tool(
    mcp.Tool(
      name: "gloogle_search",
      description: Some(
        "Search Gloogle for Gleam functions and types by name or signature",
      ),
      input_schema: object_schema(
        [string_property("query", "Name or type signature to search for")],
        ["query"],
      ),
      annotations: Some(read_only_annotations("Search Gloogle", True)),
    ),
    global.gloogle_search_handler,
  )
  |> server.add_tool(
    mcp.Tool(
      name: "search_hex_packages",
      description: Some("Search Hex for Gleam packages"),
      input_schema: object_schema(
        [string_property("query", "Hex package search query")],
        ["query"],
      ),
      annotations: Some(read_only_annotations("Search Hex packages", True)),
    ),
    hex.search_packages_handler,
  )
  |> server.add_tool(
    mcp.Tool(
      name: "get_package_releases",
      description: Some("List recent releases for a Hex package"),
      input_schema: object_schema(
        [string_property("package_name", "Lowercase Hex package name")],
        ["package_name"],
      ),
      annotations: Some(read_only_annotations("Get Hex package releases", True)),
    ),
    hex.get_package_releases_handler,
  )
  |> server.build
}

fn read_only_annotations(title: String, open_world: Bool) {
  mcp.ToolAnnotations(
    title: Some(title),
    read_only_hint: Some(True),
    destructive_hint: Some(False),
    idempotent_hint: Some(True),
    open_world_hint: Some(open_world),
  )
}

fn project_schema() {
  object_schema(
    [
      string_property(
        "project_path",
        "Path to the Gleam project; defaults to the server working directory",
      ),
    ],
    [],
  )
}

fn string_property(name: String, description: String) -> #(String, json.Json) {
  #(
    name,
    json.object([
      #("type", json.string("string")),
      #("description", json.string(description)),
    ]),
  )
}

fn object_schema(
  properties: List(#(String, json.Json)),
  required: List(String),
) {
  json.object([
    #("type", json.string("object")),
    #("properties", json.object(properties)),
    #("required", json.array(required, json.string)),
    #("additionalProperties", json.bool(False)),
  ])
  |> mcp_ffi.unsafe_coerce
}

fn loop(mcp_server) {
  case erl_read_line() {
    Ok(line) -> {
      case server.handle_message(mcp_server, line) {
        Ok(Some(response)) -> {
          io.println(json.to_string(response))
          loop(mcp_server)
        }
        Ok(None) -> loop(mcp_server)
        Error(error) -> {
          io.println(json.to_string(error))
          loop(mcp_server)
        }
      }
    }
    Error(_) -> Nil
  }
}
