import gleam/dynamic.{type Dynamic}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type DecodeError {
  DecodeError(expected: String, found: String, path: List(String))
}

pub type RootSchema {
  RootSchema(definitions: List(#(String, Schema)), schema: Schema)
}

pub type Type {
  Boolean
  String
  Number
  Integer
  ArrayType
  ObjectType
  Null
}

pub type Schema {
  Empty(metadata: List(#(String, Dynamic)))
  Type(nullable: Bool, metadata: List(#(String, Dynamic)), type_: Type)
  Enum(
    nullable: Bool,
    metadata: List(#(String, Dynamic)),
    variants: List(String),
  )
  Object(
    nullable: Bool,
    metadata: List(#(String, Dynamic)),
    schema: ObjectSchema,
  )
  Array(nullable: Bool, metadata: List(#(String, Dynamic)), items: Schema)
  Ref(nullable: Bool, metadata: List(#(String, Dynamic)), ref: String)
  OneOf(
    nullable: Bool,
    metadata: List(#(String, Dynamic)),
    schemas: List(Schema),
  )
  AllOf(
    nullable: Bool,
    metadata: List(#(String, Dynamic)),
    schemas: List(Schema),
  )
  AnyOf(
    nullable: Bool,
    metadata: List(#(String, Dynamic)),
    schemas: List(Schema),
  )
  Not(nullable: Bool, metadata: List(#(String, Dynamic)), schema: Schema)
}

pub type ObjectSchema {
  ObjectSchema(
    properties: List(#(String, Schema)),
    required: List(String),
    additional_properties: Option(Schema),
    pattern_properties: List(#(String, Schema)),
  )
}

pub fn to_json(schema: RootSchema) -> Json {
  let properties = schema_to_json(schema.schema)
  let properties = case schema.definitions {
    [] -> properties
    definitions -> {
      let definitions =
        list.map(definitions, fn(definition) {
          #(definition.0, json.object(schema_to_json(definition.1)))
        })
      [#("$defs", json.object(definitions)), ..properties]
    }
  }

  json.object(properties)
}

pub fn object_schema_to_json(schema: ObjectSchema) -> List(#(String, Json)) {
  let props_json = fn(props: List(#(String, Schema))) {
    json.object(
      list.map(props, fn(property) {
        #(property.0, json.object(schema_to_json(property.1)))
      }),
    )
  }

  let ObjectSchema(
    properties:,
    required:,
    additional_properties:,
    pattern_properties:,
  ) = schema

  let data = []

  let data = case pattern_properties {
    [] -> data
    p -> [#("patternProperties", props_json(p)), ..data]
  }

  let data = case additional_properties {
    None -> data
    Some(s) -> [
      #("additionalProperties", json.object(schema_to_json(s))),
      ..data
    ]
  }

  let data = case required {
    [] -> data
    r -> [#("required", json.array(r, json.string)), ..data]
  }

  let data = case properties {
    [] -> data
    p -> [#("properties", props_json(p)), ..data]
  }

  data
}

fn schema_to_json(schema: Schema) -> List(#(String, Json)) {
  case schema {
    Empty(metadata:) ->
      []
      |> add_metadata(metadata)
    Ref(nullable:, metadata:, ref:) ->
      [#("$ref", json.string(ref))]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    Type(nullable:, metadata:, type_:) ->
      [#("type", type_to_json(type_))]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    Enum(nullable:, metadata:, variants:) ->
      [#("enum", json.array(variants, json.string))]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    Array(nullable:, metadata:, items:) ->
      [#("items", json.object(schema_to_json(items)))]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    Object(nullable:, metadata:, schema:) ->
      object_schema_to_json(schema)
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    OneOf(nullable:, metadata:, schemas:) ->
      [
        #(
          "oneOf",
          json.array(schemas, fn(s) { json.object(schema_to_json(s)) }),
        ),
      ]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    AllOf(nullable:, metadata:, schemas:) ->
      [
        #(
          "allOf",
          json.array(schemas, fn(s) { json.object(schema_to_json(s)) }),
        ),
      ]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    AnyOf(nullable:, metadata:, schemas:) ->
      [
        #(
          "anyOf",
          json.array(schemas, fn(s) { json.object(schema_to_json(s)) }),
        ),
      ]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
    Not(nullable:, metadata:, schema:) ->
      [#("not", json.object(schema_to_json(schema)))]
      |> add_nullable(nullable)
      |> add_metadata(metadata)
  }
}

fn type_to_json(t: Type) -> Json {
  json.string(case t {
    Boolean -> "boolean"
    String -> "string"
    Number -> "number"
    Integer -> "integer"
    ArrayType -> "array"
    ObjectType -> "object"
    Null -> "null"
  })
}

pub fn decode_root_schema(
  data: Dynamic,
) -> Result(RootSchema, List(DecodeError)) {
  let definitions_loader = fn() {
    case get_map_value(data, "$defs") {
      Ok(defs_val) -> {
        use defs_list <- result.try(map_to_list(defs_val))
        let results =
          list.fold(defs_list, Ok([]), fn(acc, pair) {
            use acc_list <- result.try(acc)
            use schema <- result.try(decode_schema(pair.1))
            Ok([#(pair.0, schema), ..acc_list])
          })
        results |> result.map(list.reverse)
      }
      Error(_) -> {
        case get_map_value(data, "definitions") {
          Ok(defs_val) -> {
            use defs_list <- result.try(map_to_list(defs_val))
            let results =
              list.fold(defs_list, Ok([]), fn(acc, pair) {
                use acc_list <- result.try(acc)
                use schema <- result.try(decode_schema(pair.1))
                Ok([#(pair.0, schema), ..acc_list])
              })
            results |> result.map(list.reverse)
          }
          Error(_) -> Ok([])
        }
      }
    }
  }

  use definitions <- result.try(definitions_loader())
  use schema <- result.try(decode_schema(data))
  Ok(RootSchema(definitions, schema))
}

pub fn decode_schema(data: Dynamic) -> Result(Schema, List(DecodeError)) {
  case is_map(data) {
    True -> {
      let decoder =
        key_decoder(data, "enum", decode_enum_local)
        |> result.lazy_or(fn() { key_decoder(data, "$ref", decode_ref_local) })
        |> result.lazy_or(fn() {
          key_decoder(data, "items", decode_array_local)
        })
        |> result.lazy_or(fn() {
          key_decoder(data, "properties", decode_object_local)
        })
        |> result.lazy_or(fn() {
          key_decoder(data, "oneOf", decode_one_of_local)
        })
        |> result.lazy_or(fn() {
          key_decoder(data, "anyOf", decode_any_of_local)
        })
        |> result.lazy_or(fn() {
          key_decoder(data, "allOf", decode_all_of_local)
        })
        |> result.lazy_or(fn() { key_decoder(data, "not", decode_not_local) })
        |> result.lazy_or(fn() { key_decoder(data, "type", decode_type_local) })
        |> result.unwrap(fn() { decode_empty_local(data) })

      decoder()
    }
    False ->
      Error([DecodeError(expected: "Map", found: "wrong type", path: [])])
  }
}

fn key_decoder(
  data: Dynamic,
  key: String,
  constructor: fn(Dynamic, Dynamic) -> Result(t, List(DecodeError)),
) -> Result(fn() -> Result(t, List(DecodeError)), Nil) {
  case get_map_value(data, key) {
    Ok(value) -> Ok(fn() { constructor(value, data) })
    Error(_) -> Error(Nil)
  }
}

fn decode_enum_local(
  variants: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  case is_list(variants) {
    True -> {
      let results = list.map(list_to_gleam(variants), dynamic_string)
      case result.all(results) {
        Ok(strings) -> Ok(Enum(nullable, metadata, strings))
        Error(e) -> Error(e) |> push_path("enum")
      }
    }
    False ->
      Error([DecodeError(expected: "List", found: "wrong type", path: ["enum"])])
  }
}

fn decode_ref_local(
  ref: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  case dynamic_string(ref) {
    Ok(r) -> Ok(Ref(nullable, metadata, r))
    Error(e) -> Error(e) |> push_path("$ref")
  }
}

fn decode_array_local(
  items: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  case decode_schema(items) {
    Ok(s) -> Ok(Array(nullable, metadata, s))
    Error(e) -> Error(e) |> push_path("items")
  }
}

fn decode_object_local(
  _props: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  decode_object_schema(data)
  |> result.map(Object(nullable, metadata, _))
}

fn decode_one_of_local(
  schemas: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  case is_list(schemas) {
    True -> {
      let results = list.map(list_to_gleam(schemas), decode_schema)
      case result.all(results) {
        Ok(schemas_list) -> Ok(OneOf(nullable, metadata, schemas_list))
        Error(e) -> Error(e) |> push_path("oneOf")
      }
    }
    False ->
      Error([
        DecodeError(expected: "List", found: "wrong type", path: ["oneOf"]),
      ])
  }
}

fn decode_any_of_local(
  schemas: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  case is_list(schemas) {
    True -> {
      let results = list.map(list_to_gleam(schemas), decode_schema)
      case result.all(results) {
        Ok(schemas_list) -> Ok(AnyOf(nullable, metadata, schemas_list))
        Error(e) -> Error(e) |> push_path("anyOf")
      }
    }
    False ->
      Error([
        DecodeError(expected: "List", found: "wrong type", path: ["anyOf"]),
      ])
  }
}

fn decode_all_of_local(
  schemas: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  case is_list(schemas) {
    True -> {
      let results = list.map(list_to_gleam(schemas), decode_schema)
      case result.all(results) {
        Ok(schemas_list) -> Ok(AllOf(nullable, metadata, schemas_list))
        Error(e) -> Error(e) |> push_path("allOf")
      }
    }
    False ->
      Error([
        DecodeError(expected: "List", found: "wrong type", path: ["allOf"]),
      ])
  }
}

fn decode_not_local(
  schema: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))
  case decode_schema(schema) {
    Ok(s) -> Ok(Not(nullable, metadata, s))
    Error(e) -> Error(e) |> push_path("not")
  }
}

fn decode_type_local(
  type_val: Dynamic,
  data: Dynamic,
) -> Result(Schema, List(DecodeError)) {
  let type_res = case dynamic_string(type_val) {
    Ok(s) -> Ok(s)
    Error(_) -> {
      case is_list(type_val) {
        True -> {
          case list_to_gleam(type_val) {
            [t, ..] -> dynamic_string(t)
            _ -> Ok("object")
          }
        }
        False -> Ok("object")
      }
    }
  }

  use type_str <- result.try(type_res |> push_path("type"))
  use nullable <- result.try(get_nullable(data))
  use metadata <- result.try(get_metadata(data))

  case type_str {
    "boolean" -> Ok(Type(nullable, metadata, Boolean))
    "string" -> Ok(Type(nullable, metadata, String))
    "number" -> Ok(Type(nullable, metadata, Number))
    "integer" -> Ok(Type(nullable, metadata, Integer))
    "array" -> Ok(Type(nullable, metadata, ArrayType))
    "object" -> Ok(Type(nullable, metadata, ObjectType))
    "null" -> Ok(Type(nullable, metadata, Null))
    _ -> Error([DecodeError(expected: "Type", found: type_str, path: ["type"])])
  }
}

fn decode_empty_local(data: Dynamic) -> Result(Schema, List(DecodeError)) {
  use metadata <- result.try(get_metadata(data))
  Ok(Empty(metadata:))
}

pub fn decode_object_schema(
  data: Dynamic,
) -> Result(ObjectSchema, List(DecodeError)) {
  let properties_field = fn(name) {
    case get_map_value(data, name) {
      Ok(inner_val) -> {
        use inner_list <- result.try(map_to_list(inner_val) |> push_path(name))
        let results =
          list.fold(inner_list, Ok([]), fn(acc, pair) {
            use acc_list <- result.try(acc)
            use schema <- result.try(decode_schema(pair.1))
            Ok([#(pair.0, schema), ..acc_list])
          })
        results |> result.map(list.reverse)
      }
      Error(_) -> Ok([])
    }
  }

  let required_field = fn() {
    case get_map_value(data, "required") {
      Ok(r_val) -> {
        case is_list(r_val) {
          True -> {
            let strings = list.map(list_to_gleam(r_val), dynamic_string)
            result.all(strings) |> push_path("required")
          }
          False ->
            Error([
              DecodeError(expected: "List", found: "wrong type", path: [
                "required",
              ]),
            ])
        }
      }
      Error(_) -> Ok([])
    }
  }

  let additional_properties_field = fn() {
    case get_map_value(data, "additionalProperties") {
      Ok(inner) -> {
        case dynamic_bool(inner) {
          Ok(True) -> Ok(Some(Empty([])))
          Ok(False) -> Ok(None)
          Error(_) -> decode_schema(inner) |> result.map(Some)
        }
      }
      Error(_) -> Ok(Some(Empty([])))
    }
  }

  use properties <- result.try(properties_field("properties"))
  use required <- result.try(required_field())
  use additional_properties <- result.try(additional_properties_field())
  use pattern_properties <- result.try(properties_field("patternProperties"))

  Ok(ObjectSchema(
    properties,
    required,
    additional_properties,
    pattern_properties,
  ))
}

fn push_path(
  res: Result(t, List(DecodeError)),
  segment: String,
) -> Result(t, List(DecodeError)) {
  result.map_error(res, fn(errors) {
    list.map(errors, fn(e) { DecodeError(..e, path: [segment, ..e.path]) })
  })
}

fn get_metadata(
  data: Dynamic,
) -> Result(List(#(String, Dynamic)), List(DecodeError)) {
  use data_list <- result.try(map_to_list(data))
  let ignored_keys =
    set_from_list([
      "type", "enum", "$ref", "items", "properties", "required",
      "additionalProperties", "patternProperties", "oneOf", "anyOf", "allOf",
      "not", "$defs", "definitions", "nullable",
    ])

  let metadata =
    list.filter(data_list, fn(pair) { !set_contains(ignored_keys, pair.0) })
  Ok(metadata)
}

fn get_nullable(data: Dynamic) -> Result(Bool, List(DecodeError)) {
  case get_map_value(data, "nullable") {
    Ok(val) -> dynamic_bool(val) |> push_path("nullable")
    Error(_) -> {
      case get_map_value(data, "type") {
        Ok(t_val) -> {
          case is_list(t_val) {
            True -> {
              let res = list.map(list_to_gleam(t_val), dynamic_string)
              case result.all(res) {
                Ok(s_list) -> Ok(list.contains(s_list, "null"))
                _ -> Ok(False)
              }
            }
            False -> Ok(False)
          }
        }
        Error(_) -> Ok(False)
      }
    }
  }
}

fn metadata_value_to_json(data: Dynamic) -> Json {
  case dynamic_string(data) {
    Ok(s) -> json.string(s)
    Error(_) -> {
      case dynamic_int(data) {
        Ok(i) -> json.int(i)
        Error(_) -> {
          case dynamic_bool(data) {
            Ok(b) -> json.bool(b)
            Error(_) -> json.string(string.inspect(data))
          }
        }
      }
    }
  }
}

fn add_metadata(
  data: List(#(String, Json)),
  metadata: List(#(String, Dynamic)),
) -> List(#(String, Json)) {
  list.fold(metadata, data, fn(acc, meta) {
    [#(meta.0, metadata_value_to_json(meta.1)), ..acc]
  })
}

fn add_nullable(
  data: List(#(String, Json)),
  nullable: Bool,
) -> List(#(String, Json)) {
  case nullable {
    False -> data
    True -> [#("nullable", json.bool(True)), ..data]
  }
}

// FFI
@external(erlang, "mcp_ffi", "is_binary")
fn is_binary(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "is_integer")
fn is_integer(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "is_boolean")
fn is_boolean(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "is_list")
fn is_list(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "is_map")
fn is_map(v: Dynamic) -> Bool

@external(erlang, "mcp_ffi", "get_map_value")
fn erl_get_map_value(m: Dynamic, k: String) -> Result(Dynamic, Nil)

fn get_map_value(m: Dynamic, k: String) -> Result(Dynamic, List(DecodeError)) {
  case erl_get_map_value(m, k) {
    Ok(v) -> Ok(v)
    Error(_) ->
      Error([DecodeError(expected: "Key " <> k, found: "missing", path: [])])
  }
}

@external(erlang, "mcp_ffi", "map_to_list")
fn erl_map_to_list(m: Dynamic) -> List(#(String, Dynamic))

fn map_to_list(
  m: Dynamic,
) -> Result(List(#(String, Dynamic)), List(DecodeError)) {
  case is_map(m) {
    True -> Ok(erl_map_to_list(m))
    False ->
      Error([DecodeError(expected: "Map", found: "wrong type", path: [])])
  }
}

@external(erlang, "mcp_ffi", "list_to_gleam")
fn list_to_gleam(l: Dynamic) -> List(Dynamic)

// Manual string decoding
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

fn dynamic_bool(data: Dynamic) -> Result(Bool, List(DecodeError)) {
  case is_boolean(data) {
    True -> Ok(unsafe_coerce(data))
    False ->
      Error([DecodeError(expected: "Bool", found: "wrong type", path: [])])
  }
}

// Sneaky reuse
@external(erlang, "mcp_ffi", "list_to_gleam")
@external(javascript, "../mcp_ffi", "unsafe_coerce")
fn unsafe_coerce(a: any) -> b

// Fake set helpers
fn set_from_list(l: List(String)) -> List(String) {
  l
}

fn set_contains(l: List(String), s: String) -> Bool {
  list.contains(l, s)
}
