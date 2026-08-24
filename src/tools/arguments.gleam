import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub fn required_string(
  arguments: Option(Dynamic),
  field: String,
) -> Result(String, String) {
  use data <- result.try(case arguments {
    Some(data) -> Ok(data)
    None -> Error("Missing arguments object")
  })
  let decoder = {
    use value <- decode.field(field, decode.string)
    decode.success(value)
  }
  use value <- result.try(
    decode.run(data, decoder)
    |> result.map_error(fn(_) { "Expected '" <> field <> "' to be a string" }),
  )
  non_empty(value, field)
}

pub fn optional_string(
  arguments: Option(Dynamic),
  field: String,
  default: String,
) -> Result(String, String) {
  case arguments {
    None -> Ok(default)
    Some(data) -> {
      let decoder = {
        use value <- decode.optional_field(field, default, decode.string)
        decode.success(value)
      }
      decode.run(data, decoder)
      |> result.map_error(fn(_) { "Expected '" <> field <> "' to be a string" })
    }
  }
}

pub fn query(
  arguments: Option(Dynamic),
  field: String,
) -> Result(String, String) {
  use value <- result.try(required_string(arguments, field))
  case string.length(value) > 200 {
    True -> Error("'" <> field <> "' must be 200 characters or fewer")
    False -> Ok(value)
  }
}

fn non_empty(value: String, field: String) -> Result(String, String) {
  let value = string.trim(value)
  case value {
    "" -> Error("'" <> field <> "' must not be empty")
    _ -> Ok(value)
  }
}
