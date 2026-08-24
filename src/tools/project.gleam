import filepath
import gleam/result
import simplifile

pub fn validate(path: String) -> Result(String, String) {
  use is_directory <- result.try(
    simplifile.is_directory(path)
    |> result.map_error(fn(_) { "Could not access project directory: " <> path }),
  )
  use <- bool_result(is_directory, "Project directory does not exist: " <> path)

  let manifest = filepath.join(path, "gleam.toml")
  use is_manifest <- result.try(
    simplifile.is_file(manifest)
    |> result.map_error(fn(_) {
      "Could not access project manifest: " <> manifest
    }),
  )
  use <- bool_result(is_manifest, "No gleam.toml found at: " <> manifest)
  Ok(path)
}

fn bool_result(value: Bool, error: String, next: fn() -> Result(a, String)) {
  case value {
    True -> next()
    False -> Error(error)
  }
}
