import filepath
import gleam/string
import simplifile
import tools/command
import tools/diagnostics

const project_path = "/tmp/gleam docs mcp project;false"

pub fn command_runner_captures_and_truncates_test() {
  let assert Ok(command.CommandResult(0, "1234", True)) =
    command.run("sh", ["-c", "printf 123456789"], ".", 5000, 4)
}

pub fn command_runner_times_out_test() {
  let assert Error("Command timed out") =
    command.run("sh", ["-c", "sleep 1"], ".", 10, 100)
}

pub fn missing_executable_is_error_test() {
  let assert Error(message) =
    command.run("definitely-not-a-real-command", [], ".", 1000, 100)
  assert string.contains(message, "Executable not found")
}

pub fn diagnostics_handles_shell_metacharacter_path_test() {
  let _ = simplifile.delete_all([project_path])
  let assert Ok(Nil) =
    simplifile.create_directory_all(filepath.join(project_path, "src"))
  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(project_path, "gleam.toml"),
      "name = \"fixture\"\nversion = \"1.0.0\"\n",
    )
  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(project_path, "src/fixture.gleam"),
      "pub fn main() { Nil }",
    )

  let assert Ok(output) = diagnostics.get_compiler_diagnostics(project_path)
  assert string.contains(output, "gleam check exited with code 0")

  let assert Ok(Nil) =
    simplifile.write(
      filepath.join(project_path, "src/fixture.gleam"),
      "pub fn main() {",
    )
  let assert Ok(diagnostics) =
    diagnostics.get_compiler_diagnostics(project_path)
  assert string.contains(diagnostics, "gleam check exited with code 1")
  assert string.contains(diagnostics, "Syntax error")

  let assert Ok(Nil) = simplifile.delete(project_path)
}
