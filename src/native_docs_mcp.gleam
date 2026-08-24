import gleam/io
import gleam/json
import gleam/option.{None, Some}
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp
import mcp_toolkit_gleam/core/server
import resources/popular_packages
import tools/diagnostics
import tools/discovery
import tools/eval
import tools/global
import tools/hex
import tools/scaffold
import tools/symbol

@external(erlang, "mcp_ffi", "read_line")
fn erl_read_line() -> Result(String, Nil)

pub fn main() {
  build_server()
  |> loop
}

pub fn build_server() -> server.Server {
  let server_builder =
    server.new("native-docs-mcp", "0.1.0")
    |> server.description(
      "Native Gleam MCP server for Gleam documentation and ecosystem",
    )

  let server_builder =
    server_builder
    |> server.add_tool(
      mcp.Tool(
        name: "get_compiler_diagnostics",
        description: Some("Run gleam check on a local project"),
        input_schema: object_schema(
          [
            string_property(
              "project_path",
              "Path to the Gleam project; defaults to the current directory",
            ),
          ],
          [],
        ),
        annotations: None,
      ),
      diagnostics.get_compiler_diagnostics_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "format_project",
        description: Some("Run gleam format on a local project"),
        input_schema: object_schema(
          [
            string_property(
              "project_path",
              "Path to the Gleam project; defaults to the current directory",
            ),
          ],
          [],
        ),
        annotations: None,
      ),
      diagnostics.format_project_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "list_dependencies",
        description: Some("List dependencies from gleam.toml"),
        input_schema: object_schema(
          [
            string_property(
              "project_path",
              "Path to the Gleam project; defaults to the current directory",
            ),
          ],
          [],
        ),
        annotations: None,
      ),
      discovery.list_dependencies_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "list_local_modules",
        description: Some("List modules in local src directory"),
        input_schema: object_schema(
          [
            string_property(
              "project_path",
              "Path to the Gleam project; defaults to the current directory",
            ),
          ],
          [],
        ),
        annotations: None,
      ),
      discovery.list_local_modules_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "scaffold_gleam_module",
        description: Some(
          "Safely scaffold a new Gleam module in a project's src directory",
        ),
        input_schema: object_schema(
          [
            string_property(
              "project_path",
              "Path to the Gleam project; defaults to the current directory",
            ),
            string_property(
              "module_name",
              "Module path relative to src, without the .gleam suffix",
            ),
            string_property("content", "Initial Gleam source for the module"),
          ],
          ["module_name"],
        ),
        annotations: None,
      ),
      scaffold.scaffold_module_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "get_symbol_context",
        description: Some("Get source context for a local symbol"),
        input_schema: object_schema(
          [
            string_property(
              "project_path",
              "Path to the Gleam project; defaults to the current directory",
            ),
            string_property("module_name", "Local Gleam module name"),
            string_property("symbol_name", "Symbol to locate in the module"),
          ],
          ["module_name", "symbol_name"],
        ),
        annotations: None,
      ),
      symbol.get_symbol_context_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "evaluate_snippet",
        description: Some(
          "Evaluate a Gleam code snippet in a sandboxed environment",
        ),
        input_schema: object_schema(
          [
            string_property("code", "Gleam source code to evaluate"),
          ],
          ["code"],
        ),
        annotations: None,
      ),
      eval.evaluate_snippet_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "gloogle_search",
        description: Some(
          "Search for Gleam functions by type signature or name via Gloogle",
        ),
        input_schema: object_schema(
          [
            string_property(
              "query",
              "Function name or type signature to search for",
            ),
          ],
          ["query"],
        ),
        annotations: None,
      ),
      global.gloogle_search_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "search_hex_packages",
        description: Some("Search Hex.pm for Gleam packages"),
        input_schema: object_schema(
          [
            string_property("query", "Hex package search query"),
          ],
          ["query"],
        ),
        annotations: None,
      ),
      hex.search_packages_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "get_package_releases",
        description: Some("Get releases for a Hex package"),
        input_schema: object_schema(
          [
            string_property("package_name", "Hex package name"),
          ],
          ["package_name"],
        ),
        annotations: None,
      ),
      hex.get_package_releases_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "search_functions",
        description: Some("Search for functions in a Gleam package"),
        input_schema: object_schema(
          [
            string_property("package_name", "Hex package name"),
            string_property("query", "Function-name search query"),
          ],
          ["package_name", "query"],
        ),
        annotations: None,
      ),
      hex.search_functions_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "search_types",
        description: Some("Search for types in a Gleam package"),
        input_schema: object_schema(
          [
            string_property("package_name", "Hex package name"),
            string_property("query", "Type-name search query"),
          ],
          ["package_name", "query"],
        ),
        annotations: None,
      ),
      hex.search_types_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "get_modules",
        description: Some("List modules in a Hex package"),
        input_schema: object_schema(
          [
            string_property("package_name", "Hex package name"),
          ],
          ["package_name"],
        ),
        annotations: None,
      ),
      hex.get_modules_handler,
    )
    |> server.add_tool(
      mcp.Tool(
        name: "get_module_info",
        description: Some("Get detailed documentation for a module"),
        input_schema: object_schema(
          [
            string_property("package_name", "Hex package name"),
            string_property("module_name", "Module name"),
          ],
          ["package_name", "module_name"],
        ),
        annotations: None,
      ),
      hex.get_module_info_handler,
    )
    |> server.add_resource(
      mcp.Resource(
        uri: "gleam://packages",
        name: "Popular Gleam Packages",
        description: Some("Lists popular Gleam packages from Hex.pm"),
        mime_type: Some("text/plain"),
        size: None,
        annotations: None,
      ),
      popular_packages.popular_packages_handler,
    )

  server.build(server_builder)
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
        Error(err) -> {
          io.println(json.to_string(err))
          loop(mcp_server)
        }
      }
    }
    Error(_) -> Nil
  }
}
