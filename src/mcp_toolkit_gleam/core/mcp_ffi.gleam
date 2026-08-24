import gleam/dynamic.{type Dynamic}

// FFI to get gleam@dynamic@decode:identity() which returns a decoder that just returns the Dynamic value
// This is needed because the current gleam_json parse() requires a decoder.
@external(erlang, "mcp_ffi", "identity_decoder")
pub fn identity_decoder() -> any

pub fn unsafe_coerce(a: any) -> b {
  mcp_ffi_unsafe_coerce(a)
}

@external(erlang, "mcp_ffi", "get_map_value")
pub fn erl_get_map_value(m: Dynamic, k: String) -> Result(Dynamic, Nil)

@external(erlang, "mcp_ffi", "identity")
fn mcp_ffi_unsafe_coerce(a: any) -> b
