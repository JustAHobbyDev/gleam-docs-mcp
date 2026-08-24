import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}
import mcp_toolkit_gleam/core/jsonrpc

pub fn response(result: Json, id: jsonrpc.Id) -> Json {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("id", id_to_json(id)),
    #("result", result),
  ])
}

pub fn error_response(
  code: Int,
  message: String,
  data: Option(Json),
  id: jsonrpc.Id,
) -> Json {
  let error_obj = [
    #("code", json.int(code)),
    #("message", json.string(message)),
  ]
  let error_obj = case data {
    Some(d) -> [#("data", d), ..error_obj]
    None -> error_obj
  }
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("id", id_to_json(id)),
    #("error", json.object(error_obj)),
  ])
}

pub fn id_to_json(id: jsonrpc.Id) -> Json {
  case id {
    jsonrpc.IdString(s) -> json.string(s)
    jsonrpc.IdInt(i) -> json.int(i)
  }
}

pub fn notification(method: String, params: Json) -> Json {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #("method", json.string(method)),
    #("params", params),
  ])
}
