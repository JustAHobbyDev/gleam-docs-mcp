//// Vendored-dependency API lookup (PROBLEM_FRAMES.md, Entry #1).
////
//// Reads the public surface of a dependency already fetched into
//// `build/packages/<dep>/src` by the Gleam build tool. Never fetches; the
//// manifest is the authority on identity, and any file that cannot be read
//// as Gleam declarations is a loud error rather than a partial listing.

import filepath
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import mcp_toolkit_gleam/core/protocol as mcp
import simplifile
import tom
import tools/arguments
import tools/project

// --- Identity resolution (domain 2) -----------------------------------------

pub type Dependency {
  Dependency(
    name: String,
    /// Semver version for Hex packages, commit for git packages.
    version: String,
    source: String,
    /// Declared in the project's own gleam.toml (dependencies or dev).
    direct: Bool,
    /// Absolute-or-relative path to build/packages/<name>.
    path: String,
  )
}

pub fn resolve(
  project_path: String,
  name: String,
) -> Result(Dependency, String) {
  use project_path <- result.try(project.validate(project_path))
  use name <- result.try(validate_name(name, "dependency"))
  let manifest_path = filepath.join(project_path, "manifest.toml")
  use content <- result.try(
    simplifile.read(manifest_path)
    |> result.map_error(fn(_) {
      "No manifest.toml at "
      <> manifest_path
      <> "; run `gleam deps download` in the project first"
    }),
  )
  use doc <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_) { "Could not parse " <> manifest_path }),
  )
  let packages = case tom.get_array(doc, ["packages"]) {
    Ok(entries) -> entries
    Error(_) -> []
  }
  use entry <- result.try(
    list.find_map(packages, fn(entry) {
      case entry {
        tom.Table(fields) | tom.InlineTable(fields) ->
          case dict.get(fields, "name") {
            Ok(tom.String(n)) if n == name -> Ok(fields)
            _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    })
    |> result.map_error(fn(_) {
      "Dependency '"
      <> name
      <> "' is not in "
      <> manifest_path
      <> "; run `gleam add "
      <> name
      <> "` to declare and fetch it"
    }),
  )
  let source = string_field(entry, "source", "hex")
  use <- fail_if(
    source == "local",
    "Dependency '"
      <> name
      <> "' is a path dependency; it is not vendored under build/packages and is outside this tool's scope",
  )
  let version = case source {
    "git" -> string_field(entry, "commit", string_field(entry, "version", "?"))
    _ -> string_field(entry, "version", "?")
  }
  let path = filepath.join(filepath.join(project_path, "build/packages"), name)
  use fetched <- result.try(
    simplifile.is_directory(path)
    |> result.map_error(fn(_) { "Could not access " <> path }),
  )
  use <- fail_if(
    !fetched,
    "Dependency '"
      <> name
      <> "' is declared in the manifest at "
      <> version
      <> " but is not fetched under "
      <> path
      <> "; run `gleam deps download` in the project",
  )
  let direct = is_direct(project_path, name)
  Ok(Dependency(name:, version:, source:, direct:, path:))
}

fn string_field(
  fields: dict.Dict(String, tom.Toml),
  key: String,
  default: String,
) -> String {
  case dict.get(fields, key) {
    Ok(tom.String(s)) -> s
    _ -> default
  }
}

fn is_direct(project_path: String, name: String) -> Bool {
  let toml_path = filepath.join(project_path, "gleam.toml")
  case simplifile.read(toml_path) {
    Ok(content) ->
      case tom.parse(content) {
        Ok(doc) ->
          // Both dev-dependency spellings are accepted by Gleam.
          result.is_ok(tom.get(doc, ["dependencies", name]))
          || result.is_ok(tom.get(doc, ["dev-dependencies", name]))
          || result.is_ok(tom.get(doc, ["dev_dependencies", name]))
        Error(_) -> False
      }
    Error(_) -> False
  }
}

fn validate_name(value: String, what: String) -> Result(String, String) {
  let value = string.trim(value)
  let allowed = case what {
    "module" -> "abcdefghijklmnopqrstuvwxyz0123456789_/"
    _ -> "abcdefghijklmnopqrstuvwxyz0123456789_"
  }
  let ok =
    value != ""
    && !string.contains(value, "//")
    && !string.starts_with(value, "/")
    && !string.ends_with(value, "/")
    && list.all(string.to_graphemes(value), string.contains(allowed, _))
  case ok {
    True -> Ok(value)
    False ->
      Error(
        "Invalid "
        <> what
        <> " name '"
        <> value
        <> "': expected lowercase "
        <> case what {
          "module" -> "letters, digits, underscores and slashes"
          _ -> "letters, digits and underscores"
        },
      )
  }
}

fn fail_if(condition: Bool, error: String, next: fn() -> Result(a, String)) {
  case condition {
    True -> Error(error)
    False -> next()
  }
}

// --- Module listing -----------------------------------------------------------

pub fn list_modules(dep: Dependency) -> Result(List(String), String) {
  let src = filepath.join(dep.path, "src")
  use files <- result.try(
    simplifile.get_files(src)
    |> result.map_error(fn(_) { "Could not list files in " <> src }),
  )
  let prefix_length = string.length(src) + 1
  files
  |> list.filter(string.ends_with(_, ".gleam"))
  |> list.map(fn(path) {
    path |> string.drop_start(prefix_length) |> filepath.strip_extension
  })
  |> list.sort(string.compare)
  |> Ok
}

// --- Public-surface extraction (domain 4) -------------------------------------

pub type Kind {
  Function
  Type
  Constant
}

pub type Item {
  Item(
    kind: Kind,
    name: String,
    /// The declaration text with the body removed (signature / constructors).
    text: String,
    docs: List(String),
    deprecated: Option(String),
  )
}

pub type Surface {
  Surface(module_docs: List(String), items: List(Item), internal_count: Int)
}

type Pending {
  Pending(docs: List(String), deprecated: Option(String), internal: Bool)
}

const no_pending = Pending(docs: [], deprecated: None, internal: False)

/// Extract the public, documented declarations from Gleam source. `file` is
/// only used in error messages. Errors on any construct that cannot be
/// delimited, so a result is either complete or absent — never partial.
pub fn extract(source: String, file: String) -> Result(Surface, String) {
  let lines = string.split(source, "\n")
  walk(lines, 1, file, no_pending, Surface([], [], 0))
}

fn walk(
  lines: List(String),
  line_no: Int,
  file: String,
  pending: Pending,
  acc: Surface,
) -> Result(Surface, String) {
  case lines {
    [] -> Ok(Surface(..acc, items: list.reverse(acc.items)))
    [line, ..rest] -> {
      let next = fn(p, a) { walk(rest, line_no + 1, file, p, a) }
      case line {
        "////" <> doc ->
          next(
            pending,
            Surface(..acc, module_docs: [trim_doc(doc), ..acc.module_docs]),
          )
        "///" <> doc ->
          next(Pending(..pending, docs: [trim_doc(doc), ..pending.docs]), acc)
        "@internal" <> _ -> next(Pending(..pending, internal: True), acc)
        "@deprecated" <> reason ->
          next(
            Pending(..pending, deprecated: Some(attribute_reason(reason))),
            acc,
          )
        "@" <> _ -> next(pending, acc)
        "pub fn " <> _ -> {
          use #(text, consumed) <- result.try(take_signature(
            lines,
            line_no,
            file,
          ))
          finish(rest, line_no, consumed, file, pending, acc, Function, text)
        }
        "pub opaque type " <> _ -> {
          use #(text, consumed) <- result.try(take_type(lines, line_no, file))
          let head = case string.split_once(text, " {") {
            Ok(#(head, _)) -> head
            Error(_) -> text
          }
          finish(rest, line_no, consumed, file, pending, acc, Type, head)
        }
        "pub type " <> _ -> {
          use #(text, consumed) <- result.try(take_type(lines, line_no, file))
          finish(rest, line_no, consumed, file, pending, acc, Type, text)
        }
        "pub const " <> _ -> {
          let text = case ends_open(line) {
            True -> line <> " …"
            False -> line
          }
          finish(rest, line_no, 1, file, pending, acc, Constant, text)
        }
        "" -> next(pending, acc)
        _ -> next(no_pending, acc)
      }
    }
  }
}

fn finish(
  rest: List(String),
  line_no: Int,
  consumed: Int,
  file: String,
  pending: Pending,
  acc: Surface,
  kind: Kind,
  text: String,
) -> Result(Surface, String) {
  let remaining = list.drop(rest, consumed - 1)
  let acc = case pending.internal {
    True -> Surface(..acc, internal_count: acc.internal_count + 1)
    False ->
      Surface(..acc, items: [
        Item(
          kind:,
          name: declaration_name(text),
          text:,
          docs: list.reverse(pending.docs),
          deprecated: pending.deprecated,
        ),
        ..acc.items
      ])
  }
  walk(remaining, line_no + consumed, file, no_pending, acc)
}

/// Accumulate a `pub fn` head until its body `{`, or — for bodiless external
/// functions — until parentheses balance and the line does not continue.
fn take_signature(
  lines: List(String),
  line_no: Int,
  file: String,
) -> Result(#(String, Int), String) {
  take(lines, line_no, file, [], 0, 0, fn(text, line, paren_depth, _brace) {
    case string.split_once(text, "{") {
      Ok(#(head, _)) -> Some(string.trim(head))
      Error(_) ->
        case
          paren_depth == 0 && string.contains(text, ")") && !ends_open(line)
        {
          True -> Some(string.trim(text))
          False -> None
        }
    }
  })
}

/// Accumulate a `pub type` until its constructor block closes, or for an
/// alias / bodiless type until the line does not continue.
fn take_type(
  lines: List(String),
  line_no: Int,
  file: String,
) -> Result(#(String, Int), String) {
  take(lines, line_no, file, [], 0, 0, fn(text, line, paren_depth, brace_depth) {
    case string.contains(text, "{") {
      True ->
        case brace_depth == 0 {
          True -> Some(string.trim(text))
          False -> None
        }
      False ->
        case paren_depth == 0 && !ends_open(line) {
          True -> Some(string.trim(text))
          False -> None
        }
    }
  })
}

fn take(
  lines: List(String),
  line_no: Int,
  file: String,
  taken: List(String),
  paren_depth: Int,
  brace_depth: Int,
  done: fn(String, String, Int, Int) -> Option(String),
) -> Result(#(String, Int), String) {
  case lines {
    [] ->
      Error(
        "Could not read declaration starting at "
        <> file
        <> ":"
        <> int.to_string(line_no)
        <> " (unterminated); the file may use syntax this tool does not understand",
      )
    [line, ..rest] -> {
      let taken = [line, ..taken]
      let #(paren_depth, brace_depth) = depths(line, paren_depth, brace_depth)
      let text = taken |> list.reverse |> string.join("\n")
      case done(text, line, paren_depth, brace_depth) {
        Some(text) -> Ok(#(text, list.length(taken)))
        None -> take(rest, line_no, file, taken, paren_depth, brace_depth, done)
      }
    }
  }
}

fn depths(line: String, paren: Int, brace: Int) -> #(Int, Int) {
  list.fold(string.to_graphemes(line), #(paren, brace), fn(d, c) {
    case c {
      "(" -> #(d.0 + 1, d.1)
      ")" -> #(d.0 - 1, d.1)
      "{" -> #(d.0, d.1 + 1)
      "}" -> #(d.0, d.1 - 1)
      _ -> d
    }
  })
}

fn ends_open(line: String) -> Bool {
  let line = string.trim_end(line)
  string.ends_with(line, "(")
  || string.ends_with(line, ",")
  || string.ends_with(line, "->")
  || string.ends_with(line, "=")
  || string.ends_with(line, "[")
  || string.ends_with(line, "<>")
}

/// The identifier of a public declaration: the first word after
/// `pub fn` / `pub type` / `pub opaque type` / `pub const`, up to any
/// `(`, `:`, `=`, `{` or whitespace.
fn declaration_name(text: String) -> String {
  let rest = case text {
    "pub opaque type " <> r -> r
    "pub type " <> r -> r
    "pub fn " <> r -> r
    "pub const " <> r -> r
    other -> other
  }
  rest
  |> string.to_graphemes
  |> list.take_while(fn(c) {
    !list.contains(["(", ":", "=", "{", " ", "\n", "\t"], c)
  })
  |> string.concat
}

fn trim_doc(doc: String) -> String {
  case doc {
    " " <> rest -> rest
    _ -> doc
  }
}

fn attribute_reason(rest: String) -> String {
  rest
  |> string.trim
  |> string.drop_start(1)
  |> string.drop_end(1)
  |> string.trim
  |> string.drop_start(1)
  |> string.drop_end(1)
}

// --- JSON output ---------------------------------------------------------------

pub fn get_dependency_api(
  project_path: String,
  name: String,
  module: Option(String),
) -> Result(String, String) {
  get_dependency_api_json(project_path, name, module)
  |> result.map(json.to_string)
}

pub fn get_dependency_api_json(
  project_path: String,
  name: String,
  module: Option(String),
) -> Result(json.Json, String) {
  use dep <- result.try(resolve(project_path, name))
  case module {
    None -> {
      use modules <- result.try(list_modules(dep))
      Ok(
        json.object(
          list.append(identity_fields(dep), [
            #("modules", json.array(modules, json.string)),
          ]),
        ),
      )
    }
    Some(module) -> {
      use module <- result.try(validate_name(module, "module"))
      let file =
        filepath.join(filepath.join(dep.path, "src"), module <> ".gleam")
      use source <- result.try(
        simplifile.read(file)
        |> result.map_error(fn(_) {
          "Module '"
          <> module
          <> "' not found in "
          <> dep.name
          <> " "
          <> dep.version
          <> " (expected "
          <> file
          <> "); call without `module` to list its modules"
        }),
      )
      use surface <- result.try(extract(source, file))
      Ok(
        json.object(
          list.append(identity_fields(dep), [
            #("module", json.string(module)),
            #("file", json.string(file)),
            #(
              "module_docs",
              json.string(string.join(list.reverse(surface.module_docs), "\n")),
            ),
            #("items", json.array(surface.items, item_to_json)),
            #("internal_omitted", json.int(surface.internal_count)),
          ]),
        ),
      )
    }
  }
}

/// Identity of what was read (R1) and directness (R3). `import_note` is
/// present only for transitive dependencies, because the compiler rejects
/// imports from packages not declared in gleam.toml.
fn identity_fields(dep: Dependency) -> List(#(String, json.Json)) {
  let base = [
    #("dependency", json.string(dep.name)),
    #("version", json.string(dep.version)),
    #("source", json.string(dep.source)),
    #("direct", json.bool(dep.direct)),
    #("path", json.string(dep.path)),
  ]
  case dep.direct {
    True -> base
    False ->
      list.append(base, [
        #(
          "import_note",
          json.string(
            "Transitive dependency: not declared in gleam.toml; run `gleam add "
            <> dep.name
            <> "` before importing it",
          ),
        ),
      ])
  }
}

fn item_to_json(item: Item) -> json.Json {
  json.object([
    #(
      "kind",
      json.string(case item.kind {
        Function -> "function"
        Type -> "type"
        Constant -> "constant"
      }),
    ),
    #("name", json.string(item.name)),
    #("signature", json.string(item.text)),
    #("docs", json.string(string.join(item.docs, "\n"))),
    #("deprecated", json.nullable(item.deprecated, json.string)),
  ])
}

// --- MCP handler --------------------------------------------------------------

pub fn get_dependency_api_handler(
  req: mcp.CallToolRequest(Dynamic),
) -> Result(mcp.CallToolResult, String) {
  use project_path <- result.try(arguments.optional_string(
    req.arguments,
    "project_path",
    ".",
  ))
  use dependency <- result.try(arguments.required_string(
    req.arguments,
    "dependency",
  ))
  use module <- result.try(arguments.optional_string(
    req.arguments,
    "module",
    "",
  ))
  let module = case string.trim(module) {
    "" -> None
    m -> Some(m)
  }
  use output <- result.try(get_dependency_api(project_path, dependency, module))
  Ok(mcp.CallToolResult(
    meta: None,
    content: [mcp.TextToolContent(mcp.TextContent(None, output, "text"))],
    is_error: Some(False),
  ))
}
