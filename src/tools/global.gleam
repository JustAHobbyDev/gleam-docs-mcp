import gleam/dynamic.{type Dynamic}
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import mcp_toolkit_gleam/core/mcp_ffi
import mcp_toolkit_gleam/core/protocol as mcp

/// Query the Gloogle search engine for Gleam functions by type signature or name.
pub fn gloogle_search(query: String) -> String {
  let url = "https://gloogle.run/api/search?q=" <> url_encode(query)
  case fetch_json(url) {
    Ok(dyn) -> format_results(dyn, query)
    Error(err) -> "Error querying Gloogle: " <> err
  }
}

pub fn gloogle_search_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  let query = case req.arguments {
    Some(args) -> get_string(args, "query", "")
    None -> ""
  }
  let output = gloogle_search(query)
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(string.starts_with(output, "Error")),
  ))
}

fn format_results(dyn: Dynamic, query: String) -> String {
  // The API returns a list of result objects
  let items: List(Dynamic) = mcp_ffi.unsafe_coerce(dyn)
  case items {
    [] -> "No results found on Gloogle for \"" <> query <> "\"."
    _ -> {
      let formatted =
        items
        |> list.take(10)
        |> list.map(fn(item) {
          let name = get_string(item, "name", "unknown")
          let package = get_string(item, "package_name", "")
          let module = get_string(item, "module_name", "")
          let kind = get_string(item, "kind", "")
          let signature = get_string(item, "type_", "")
          let documentation = get_string(item, "documentation", "")
          "### "
          <> name
          <> "\n"
          <> "**Package:** "
          <> package
          <> " | **Module:** "
          <> module
          <> " | **Kind:** "
          <> kind
          <> "\n"
          <> "**Signature:** `"
          <> signature
          <> "`\n"
          <> "**Synopsis:** "
          <> documentation
          <> "\n"
        })
      "## Gloogle Search Results for \""
      <> query
      <> "\"\n\n"
      <> string.join(formatted, "\n---\n\n")
    }
  }
}

fn fetch_json(url: String) -> Result(Dynamic, String) {
  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { "Invalid Gloogle API URL" }),
  )
  let req = request.set_header(req, "user-agent", "native-docs-mcp/0.1.0")

  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(_) { "Failed to connect to Gloogle" }),
  )

  case resp.status {
    200 -> {
      json.parse(resp.body, mcp_ffi.identity_decoder())
      |> result.map_error(fn(_) { "Failed to parse Gloogle response" })
    }
    _ -> Error("Gloogle API returned status " <> int_to_string(resp.status))
  }
}

fn get_string(dyn: Dynamic, key: String, default: String) -> String {
  case mcp_ffi.erl_get_map_value(dyn, key) {
    Ok(v) -> mcp_ffi.unsafe_coerce(v)
    Error(_) -> default
  }
}

/// Simple percent-encoding for URL query parameters
fn url_encode(s: String) -> String {
  string.to_graphemes(s)
  |> list.map(fn(c) {
    case c {
      " " -> "%20"
      "(" -> "%28"
      ")" -> "%29"
      "[" -> "%5B"
      "]" -> "%5D"
      "," -> "%2C"
      "-" -> "%2D"
      ">" -> "%3E"
      "<" -> "%3C"
      _ -> c
    }
  })
  |> string.join("")
}

@external(erlang, "erlang", "integer_to_binary")
fn int_to_string(i: Int) -> String
