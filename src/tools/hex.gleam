import gleam/dynamic.{type Dynamic}
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp
import tools/hex_client

pub fn search_packages_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let query = case req.arguments {
    Some(args) -> get_string(args, "query", "")
    None -> ""
  }

  case hex_client.search_packages(query) {
    Ok(packages) -> {
      let content =
        packages
        |> list.map(fn(p: hex_client.HexPackage) {
          mcp.TextToolContent(mcp.TextContent(
            annotations: None,
            type_: "text",
            text: p.name
              <> " ("
              <> p.version
              <> ")\n"
              <> p.description
              <> "\nDocs: "
              <> option.unwrap(p.docs_url, "N/A"),
          ))
        })
      Ok(mcp.CallToolResult(meta: None, content: content, is_error: Some(False)))
    }
    Error(err) -> {
      Ok(mcp.CallToolResult(
        meta: None,
        content: [
          mcp.TextToolContent(mcp.TextContent(None, "Error: " <> err, "text")),
        ],
        is_error: Some(True),
      ))
    }
  }
}

pub fn get_package_releases_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let package_name = case req.arguments {
    Some(args) -> get_string(args, "package_name", "")
    None -> ""
  }

  case hex_client.get_package_releases(package_name) {
    Ok(dyn) -> {
      // For now, just return the raw JSON string of releases
      let text =
        "Releases for " <> package_name <> ":\n" <> dynamic_to_string(dyn)
      Ok(mcp.CallToolResult(
        meta: None,
        content: [mcp.TextToolContent(mcp.TextContent(None, text, "text"))],
        is_error: Some(False),
      ))
    }
    Error(err) -> {
      Ok(mcp.CallToolResult(
        meta: None,
        content: [
          mcp.TextToolContent(mcp.TextContent(None, "Error: " <> err, "text")),
        ],
        is_error: Some(True),
      ))
    }
  }
}

pub fn get_modules_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let package_name = case req.arguments {
    Some(args) -> get_string(args, "package_name", "")
    None -> ""
  }
  case hex_client.get_package_releases(package_name) {
    Ok(dyn) -> {
      let text =
        "Modules for " <> package_name <> ":\n" <> dynamic_to_string(dyn)
      Ok(mcp.CallToolResult(
        meta: None,
        content: [mcp.TextToolContent(mcp.TextContent(None, text, "text"))],
        is_error: Some(False),
      ))
    }
    Error(err) ->
      Ok(mcp.CallToolResult(
        meta: None,
        content: [
          mcp.TextToolContent(mcp.TextContent(None, "Error: " <> err, "text")),
        ],
        is_error: Some(True),
      ))
  }
}

pub fn get_module_info_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let package_name = case req.arguments {
    Some(args) -> get_string(args, "package_name", "")
    None -> ""
  }
  let module_name = case req.arguments {
    Some(args) -> get_string(args, "module_name", "")
    None -> ""
  }
  // Placeholder: In a real implementation this would fetch from HexDocs
  let text = "Module documentation for " <> package_name <> "/" <> module_name
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, text, "text"))],
    is_error: Some(False),
  ))
}

pub fn search_functions_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let package_name = case req.arguments {
    Some(args) -> get_string(args, "package_name", "")
    None -> ""
  }
  let query = case req.arguments {
    Some(args) -> get_string(args, "query", "")
    None -> ""
  }
  let text = "Searching functions in " <> package_name <> " for: " <> query
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, text, "text"))],
    is_error: Some(False),
  ))
}

pub fn search_types_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let package_name = case req.arguments {
    Some(args) -> get_string(args, "package_name", "")
    None -> ""
  }
  let query = case req.arguments {
    Some(args) -> get_string(args, "query", "")
    None -> ""
  }
  let text = "Searching types in " <> package_name <> " for: " <> query
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, text, "text"))],
    is_error: Some(False),
  ))
}

fn get_string(dyn: Dynamic, key: String, default: String) -> String {
  case mcp_ffi.erl_get_map_value(dyn, key) {
    Ok(v) -> mcp_ffi.unsafe_coerce(v)
    Error(_) -> default
  }
}

fn dynamic_to_string(value: Dynamic) -> String {
  value
  |> mcp_ffi.unsafe_coerce
  |> json.to_string
}
