import filepath
import gleam/string
import simplifile
import tools/discovery

const project_path = "/tmp/gleam_docs_mcp_discovery_test"

pub fn dependency_and_module_discovery_test() {
  let _ = simplifile.delete_all([project_path])
  let assert Ok(Nil) =
    simplifile.create_directory_all(filepath.join(project_path, "src/nested"))
  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(project_path, "gleam.toml"),
      "name = \"fixture\"\nversion = \"1.0.0\"\n[dependencies]\ngleam_stdlib = \">= 1.0.0 and < 2.0.0\"\n[dev-dependencies]\ngleeunit = \">= 1.0.0 and < 2.0.0\"\n",
    )
  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(project_path, "src/main.gleam"),
      "pub fn main() { Nil }",
    )
  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(project_path, "src/nested/module.gleam"),
      "pub const value = 1",
    )
  let assert Ok(Nil) =
    simplifile.write(filepath.join(project_path, "src/ignored.txt"), "ignore")

  let assert Ok(dependencies) = discovery.list_dependencies(project_path)
  assert string.contains(dependencies, "gleam_stdlib")
  assert string.contains(dependencies, "gleeunit")

  let assert Ok(modules) = discovery.list_modules(project_path)
  assert modules == "### Local Modules\nmain\nnested/module"

  let assert Ok(Nil) = simplifile.delete(project_path)
}

pub fn underscore_dev_dependencies_test() {
  let path = "/tmp/gleam_docs_mcp_underscore_dev_deps_test"
  let _ = simplifile.delete_all([path])
  let assert Ok(Nil) = simplifile.create_directory_all(path)
  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(path, "gleam.toml"),
      "name = \"fixture\"\nversion = \"1.0.0\"\n[dependencies]\ngleam_stdlib = \">= 1.0.0 and < 2.0.0\"\n[dev_dependencies]\ngleeunit = \">= 1.0.0 and < 2.0.0\"\n",
    )
  let assert Ok(dependencies) = discovery.list_dependencies(path)
  assert string.contains(dependencies, "gleeunit")
  let assert Ok(Nil) = simplifile.delete(path)
}

pub fn invalid_project_is_error_test() {
  let assert Error(_) =
    discovery.list_dependencies("/tmp/does-not-exist-gleam-docs-mcp")
}

pub fn malformed_manifest_is_error_test() {
  let path = "/tmp/gleam_docs_mcp_bad_manifest_test"
  let _ = simplifile.delete_all([path])
  let assert Ok(Nil) = simplifile.create_directory_all(path)
  let assert Ok(Nil) =
    simplifile.write(filepath.join(path, "gleam.toml"), "not = [valid")
  let assert Error(_) = discovery.list_dependencies(path)
  let assert Ok(Nil) = simplifile.delete(path)
}
