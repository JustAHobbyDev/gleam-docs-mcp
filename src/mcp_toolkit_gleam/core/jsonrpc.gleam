import gleam/dynamic.{type Dynamic}
import gleam/result

pub type Id {
  IdString(String)
  IdInt(Int)
}

pub type Message {
  Request(id: Id, method: String, params: Dynamic)
  Response(id: Id, result: Dynamic)
  RPCError(id: Id, code: Int, message: String, data: Dynamic)
  Notification(method: String, params: Dynamic)
}

pub type DecodeError {
  DecodeError(expected: String, found: String, path: List(String))
}

pub fn decode_id(data: Dynamic) -> Result(Id, List(DecodeError)) {
  case is_binary(data) {
    True -> Ok(IdString(unsafe_coerce(data)))
    False ->
      case is_integer(data) {
        True -> Ok(IdInt(unsafe_coerce(data)))
        False ->
          Error([
            DecodeError(expected: "String | Int", found: "wrong type", path: []),
          ])
      }
  }
}

pub fn decode_message(data: Dynamic) -> Result(Message, List(DecodeError)) {
  case is_map(data) {
    True -> {
      case erl_get_map_value(data, "method") {
        Ok(method_val) -> {
          case dynamic_string(method_val) {
            Ok(method) -> {
              let params =
                erl_get_map_value(data, "params") |> result.unwrap(data)
              case erl_get_map_value(data, "id") {
                Ok(id_val) -> {
                  case decode_id(id_val) {
                    Ok(id) -> Ok(Request(id, method, params))
                    Error(e) -> Error(e)
                  }
                }
                Error(_) -> Ok(Notification(method, params))
              }
            }
            Error(e) -> Error(e)
          }
        }
        Error(_) -> {
          // Response or RPCError
          case erl_get_map_value(data, "id") {
            Ok(id_val) -> {
              case decode_id(id_val) {
                Ok(id) -> {
                  case erl_get_map_value(data, "error") {
                    Ok(error_val) -> {
                      case is_map(error_val) {
                        True -> {
                          case get_map_int(error_val, "code") {
                            Ok(code) -> {
                              case get_map_string(error_val, "message") {
                                Ok(message) -> {
                                  let data_inner =
                                    erl_get_map_value(error_val, "data")
                                    |> result.unwrap(data)
                                  Ok(RPCError(id, code, message, data_inner))
                                }
                                Error(e) -> Error(e)
                              }
                            }
                            Error(e) -> Error(e)
                          }
                        }
                        False ->
                          Error([
                            DecodeError(
                              expected: "Map",
                              found: "wrong type",
                              path: ["error"],
                            ),
                          ])
                      }
                    }
                    Error(_) -> {
                      let result_val =
                        erl_get_map_value(data, "result") |> result.unwrap(data)
                      Ok(Response(id, result_val))
                    }
                  }
                }
                Error(e) -> Error(e)
              }
            }
            Error(_) ->
              Error([
                DecodeError(
                  expected: "Message",
                  found: "missing id and method",
                  path: [],
                ),
              ])
          }
        }
      }
    }
    False ->
      Error([DecodeError(expected: "Map", found: "wrong type", path: [])])
  }
}

// FFI
@external(erlang, "mcp_ffi", "is_binary")
fn is_binary(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "is_integer")
fn is_integer(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "is_map")
fn is_map(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "get_map_value")
fn erl_get_map_value(m: Dynamic, k: String) -> Result(Dynamic, Nil)

@external(erlang, "mcp_ffi", "list_to_gleam")
fn unsafe_coerce(a: any) -> b

fn dynamic_string(data: Dynamic) -> Result(String, List(DecodeError)) {
  case is_binary(data) {
    True -> Ok(unsafe_coerce(data))
    False ->
      Error([DecodeError(expected: "String", found: "wrong type", path: [])])
  }
}

fn dynamic_int(data: Dynamic) -> Result(Int, List(DecodeError)) {
  case is_integer(data) {
    True -> Ok(unsafe_coerce(data))
    False ->
      Error([DecodeError(expected: "Int", found: "wrong type", path: [])])
  }
}

fn get_map_string(m: Dynamic, k: String) -> Result(String, List(DecodeError)) {
  case erl_get_map_value(m, k) {
    Ok(v) -> dynamic_string(v)
    Error(_) ->
      Error([DecodeError(expected: "Key " <> k, found: "missing", path: [])])
  }
}

fn get_map_int(m: Dynamic, k: String) -> Result(Int, List(DecodeError)) {
  case erl_get_map_value(m, k) {
    Ok(v) -> dynamic_int(v)
    Error(_) ->
      Error([DecodeError(expected: "Key " <> k, found: "missing", path: [])])
  }
}
