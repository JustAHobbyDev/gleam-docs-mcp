pub type CommandResult {
  CommandResult(exit_code: Int, output: String, truncated: Bool)
}

@external(erlang, "cli_ffi", "run")
pub fn run(
  executable: String,
  arguments: List(String),
  working_directory: String,
  timeout_ms: Int,
  max_output_bytes: Int,
) -> Result(CommandResult, String)
