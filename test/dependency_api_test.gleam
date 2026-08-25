import filepath
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile
import tools/dependency_api

const project_path = "/tmp/gleam_docs_mcp_dependency_api_test"

const manifest = "
packages = [
  { name = \"direct_dep\", version = \"2.1.0\", build_tools = [\"gleam\"], requirements = [\"trans_dep\"], otp_app = \"direct_dep\", source = \"hex\", outer_checksum = \"AA\" },
  { name = \"trans_dep\", version = \"0.3.0\", build_tools = [\"gleam\"], requirements = [], otp_app = \"trans_dep\", source = \"hex\", outer_checksum = \"BB\" },
  { name = \"unfetched\", version = \"9.9.9\", build_tools = [\"gleam\"], requirements = [], otp_app = \"unfetched\", source = \"hex\", outer_checksum = \"CC\" },
  { name = \"git_dep\", version = \"0.1.0\", build_tools = [\"gleam\"], requirements = [], otp_app = \"git_dep\", source = \"git\", repo = \"https://example.com/git_dep\", commit = \"abc123\" },
  { name = \"local_dep\", version = \"0.0.1\", build_tools = [\"gleam\"], requirements = [], otp_app = \"local_dep\", source = \"local\", path = \"../local_dep\" },
]
"

const module_source = "//// Module documentation line.
////
//// Second paragraph.

import gleam/option.{type Option}

/// Wraps a thing.
pub opaque type Wrapper(a) {
  Wrapper(inner: a)
}

pub type Shape {
  Circle(radius: Float)
  Square(Float)
}

pub type Alias =
  Result(Int, String)

/// Not public in docs.
@internal
pub fn hidden() -> Nil {
  Nil
}

/// The answer.
pub const answer: Int = 42

pub const items = [
  1,
  2,
]

/// Does the thing.
///
/// ## Examples
///
/// ```gleam
/// do_thing(1, fn(x) { x })
/// ```
pub fn do_thing(
  value: Int,
  with mapper: fn(Int) -> Int,
) -> Result(
  Int,
  Nil,
) {
  Ok(mapper(value))
}

@deprecated(\"Use do_thing instead\")
pub fn old_thing(value: Int) -> Int {
  value
}

@external(erlang, \"erlang\", \"length\")
pub fn native_length(list: List(a)) -> Int

fn private_helper() -> Nil {
  Nil
}

pub fn returns_fn(x: Int) -> fn(Int) ->
  Int {
  fn(y) { x + y }
}
"

type Item {
  Item(
    kind: String,
    name: String,
    signature: String,
    docs: String,
    deprecated: Option(String),
  )
}

type Surface {
  Surface(
    dependency: String,
    version: String,
    source: String,
    direct: Bool,
    module: String,
    module_docs: String,
    items: List(Item),
    internal_omitted: Int,
    import_note: Option(String),
  )
}

fn surface_decoder() -> decode.Decoder(Surface) {
  let item = {
    use kind <- decode.field("kind", decode.string)
    use name <- decode.field("name", decode.string)
    use signature <- decode.field("signature", decode.string)
    use docs <- decode.field("docs", decode.string)
    use deprecated <- decode.field("deprecated", decode.optional(decode.string))
    decode.success(Item(kind:, name:, signature:, docs:, deprecated:))
  }
  use dependency <- decode.field("dependency", decode.string)
  use version <- decode.field("version", decode.string)
  use source <- decode.field("source", decode.string)
  use direct <- decode.field("direct", decode.bool)
  use module <- decode.field("module", decode.string)
  use module_docs <- decode.field("module_docs", decode.string)
  use items <- decode.field("items", decode.list(item))
  use internal_omitted <- decode.field("internal_omitted", decode.int)
  use import_note <- decode.optional_field(
    "import_note",
    None,
    decode.optional(decode.string),
  )
  decode.success(Surface(
    dependency:,
    version:,
    source:,
    direct:,
    module:,
    module_docs:,
    items:,
    internal_omitted:,
    import_note:,
  ))
}

fn read_surface(dep: String, module: String) -> Surface {
  let assert Ok(out) =
    dependency_api.get_dependency_api(project_path, dep, Some(module))
  let assert Ok(surface) = json.parse(out, surface_decoder())
  surface
}

fn item(surface: Surface, name: String) -> Item {
  let assert Ok(found) = list.find(surface.items, fn(i) { i.name == name })
  found
}

fn setup() {
  let _ = simplifile.delete_all([project_path])
  let write = fn(rel: String, content: String) {
    let path = filepath.join(project_path, rel)
    let assert Ok(Nil) =
      simplifile.create_directory_all(filepath.directory_name(path))
    let assert Ok(Nil) = simplifile.write(path, content)
    Nil
  }
  write(
    "gleam.toml",
    "name = \"fixture\"\nversion = \"1.0.0\"\n[dependencies]\ndirect_dep = \">= 2.0.0 and < 3.0.0\"\n[dev-dependencies]\ngit_dep = { git = \"x\", ref = \"abc123\" }\n",
  )
  write("manifest.toml", manifest)
  write("build/packages/direct_dep/src/direct_dep.gleam", module_source)
  write(
    "build/packages/direct_dep/src/direct_dep/sub.gleam",
    "pub fn f() -> Nil {\n  Nil\n}\n",
  )
  write(
    "build/packages/direct_dep/src/direct_dep_ffi.erl",
    "-module(direct_dep_ffi).",
  )
  write(
    "build/packages/trans_dep/src/trans_dep.gleam",
    "// nothing public\nfn f() {\n  Nil\n}\n",
  )
  write("build/packages/git_dep/src/git_dep.gleam", "pub fn f(\n  a: Int,\n")
  Nil
}

pub fn module_surface_test() {
  setup()
  let surface = read_surface("direct_dep", "direct_dep")

  assert surface.dependency == "direct_dep"
  assert surface.version == "2.1.0"
  assert surface.source == "hex"
  assert surface.direct
  assert surface.import_note == None
  assert surface.module == "direct_dep"
  assert surface.module_docs
    == "Module documentation line.\n\nSecond paragraph."

  // Opaque type: head only, constructors hidden.
  let wrapper = item(surface, "Wrapper")
  assert wrapper.kind == "type"
  assert wrapper.signature == "pub opaque type Wrapper(a)"
  assert wrapper.docs == "Wraps a thing."
  // Regular type: constructors shown.
  assert item(surface, "Shape").signature
    == "pub type Shape {\n  Circle(radius: Float)\n  Square(Float)\n}"
  assert item(surface, "Alias").signature
    == "pub type Alias =\n  Result(Int, String)"
  // Constants: annotated one intact, multi-line value elided.
  let answer = item(surface, "answer")
  assert answer.kind == "constant"
  assert answer.signature == "pub const answer: Int = 42"
  assert answer.docs == "The answer."
  assert item(surface, "items").signature == "pub const items = [ …"
  // Multi-line signature with body removed; docs verbatim, including headings.
  let do_thing = item(surface, "do_thing")
  assert do_thing.kind == "function"
  assert do_thing.signature
    == "pub fn do_thing(\n  value: Int,\n  with mapper: fn(Int) -> Int,\n) -> Result(\n  Int,\n  Nil,\n)"
  assert do_thing.docs
    == "Does the thing.\n\n## Examples\n\n```gleam\ndo_thing(1, fn(x) { x })\n```"
  assert do_thing.deprecated == None
  assert item(surface, "old_thing").deprecated == Some("Use do_thing instead")
  // Bodiless external function and a signature whose `->` wraps lines.
  assert item(surface, "native_length").signature
    == "pub fn native_length(list: List(a)) -> Int"
  assert item(surface, "returns_fn").signature
    == "pub fn returns_fn(x: Int) -> fn(Int) ->\n  Int"
  // @internal excluded and counted; private items absent.
  assert list.all(surface.items, fn(i) {
    i.name != "hidden" && i.name != "private_helper"
  })
  assert surface.internal_omitted == 1
  assert list.length(surface.items) == 9
}

pub fn module_listing_test() {
  setup()
  let assert Ok(out) =
    dependency_api.get_dependency_api(project_path, "direct_dep", None)
  let decoder = {
    use dependency <- decode.field("dependency", decode.string)
    use modules <- decode.field("modules", decode.list(decode.string))
    decode.success(#(dependency, modules))
  }
  let assert Ok(#(dependency, modules)) = json.parse(out, decoder)
  assert dependency == "direct_dep"
  assert modules == ["direct_dep", "direct_dep/sub"]
}

pub fn transitive_and_empty_surface_test() {
  setup()
  let surface = read_surface("trans_dep", "trans_dep")
  assert surface.version == "0.3.0"
  assert !surface.direct
  let assert Some(note) = surface.import_note
  assert string.contains(note, "`gleam add trans_dep`")
  assert surface.items == []
  assert surface.internal_omitted == 0
}

pub fn git_identity_and_unterminated_file_test() {
  setup()
  let assert Ok(dep) = dependency_api.resolve(project_path, "git_dep")
  assert dep.version == "abc123"
  assert dep.direct
  let assert Error(error) =
    dependency_api.get_dependency_api(project_path, "git_dep", Some("git_dep"))
  assert string.contains(error, "git_dep.gleam:1")
  assert string.contains(error, "unterminated")
}

pub fn underscore_dev_dependencies_are_direct_test() {
  setup()
  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(project_path, "gleam.toml"),
      "name = \"fixture\"\nversion = \"1.0.0\"\n[dependencies]\n[dev_dependencies]\ndirect_dep = \">= 2.0.0 and < 3.0.0\"\n",
    )
  let assert Ok(dep) = dependency_api.resolve(project_path, "direct_dep")
  assert dep.direct
  let assert Ok(other) = dependency_api.resolve(project_path, "trans_dep")
  assert !other.direct
}

pub fn precondition_errors_test() {
  setup()
  let assert Error(missing) =
    dependency_api.get_dependency_api(project_path, "nope", None)
  assert string.contains(missing, "not in")
  assert string.contains(missing, "`gleam add nope`")

  let assert Error(unfetched) =
    dependency_api.get_dependency_api(project_path, "unfetched", None)
  assert string.contains(unfetched, "9.9.9")
  assert string.contains(unfetched, "`gleam deps download`")

  let assert Error(local) =
    dependency_api.get_dependency_api(project_path, "local_dep", None)
  assert string.contains(local, "path dependency")

  let assert Error(no_module) =
    dependency_api.get_dependency_api(
      project_path,
      "direct_dep",
      Some("missing"),
    )
  assert string.contains(
    no_module,
    "Module 'missing' not found in direct_dep 2.1.0",
  )

  let assert Error(traversal) =
    dependency_api.get_dependency_api(project_path, "direct_dep", Some("../x"))
  assert string.contains(traversal, "Invalid module name")
  let assert Error(bad_dep) =
    dependency_api.get_dependency_api(project_path, "../etc", None)
  assert string.contains(bad_dep, "Invalid dependency name")

  let assert Ok(Nil) = simplifile.delete(project_path)
}

pub fn no_manifest_is_error_test() {
  let path = "/tmp/gleam_docs_mcp_no_manifest_test"
  let _ = simplifile.delete_all([path])
  let assert Ok(Nil) = simplifile.create_directory_all(path)
  let assert Ok(Nil) =
    simplifile.write(filepath.join(path, "gleam.toml"), "name = \"x\"\n")
  let assert Error(error) =
    dependency_api.get_dependency_api(path, "anything", None)
  assert string.contains(error, "No manifest.toml")
  let assert Ok(Nil) = simplifile.delete(path)
}
