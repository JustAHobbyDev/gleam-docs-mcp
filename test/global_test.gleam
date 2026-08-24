import gleam/list
import gleam/string
import tools/global

pub fn gloogle_fixture_decodes_and_renders_test() {
  let function =
    "{\"type_name\":\"map\",\"documentation\":\"Transform every value.\",\"module_name\":\"gleam/list\",\"package_name\":\"gleam_stdlib\",\"version\":\"0.69.0\",\"json_signature\":{\"kind\":\"function\",\"name\":\"map\",\"parameters\":[{\"label\":\"list\",\"type\":{\"kind\":\"named\",\"name\":\"List\",\"parameters\":[{\"kind\":\"variable\",\"id\":0}]}}],\"return\":{\"kind\":\"named\",\"name\":\"List\",\"parameters\":[{\"kind\":\"variable\",\"id\":1}]}}}"
  let alias =
    "{\"type_name\":\"Pair\",\"documentation\":\"A pair.\",\"module_name\":\"example\",\"package_name\":\"sample\",\"version\":\"1.0.0\",\"json_signature\":{\"kind\":\"type-alias\",\"parameters\":2,\"alias\":{\"kind\":\"tuple\",\"elements\":[{\"kind\":\"variable\",\"id\":0},{\"kind\":\"variable\",\"id\":1}]}}}"
  let body =
    "{\"exact-type-matches\":["
    <> function
    <> "],\"exact-matches\":["
    <> alias
    <> "],\"matches\":["
    <> function
    <> "],\"searches\":[],\"docs-searches\":[],\"module-searches\":[]}"
  let assert Ok(output) = global.decode_search_response(body, "map")

  assert string.contains(output, "fn map(list: List(t0)) -> List(t1)")
  assert string.contains(output, "type Pair(t0, t1) = #(t0, t1)")
  assert string.contains(
    output,
    "https://hexdocs.pm/gleam_stdlib/0.69.0/gleam/list.html#map",
  )
  assert list.length(string.split(output, "Transform every value.")) == 2
}

pub fn empty_gloogle_fixture_test() {
  let body =
    "{\"exact-type-matches\":[],\"exact-matches\":[],\"matches\":[],\"searches\":[],\"docs-searches\":[],\"module-searches\":[]}"
  let assert Ok("No Gloogle results found for `nothing`.") =
    global.decode_search_response(body, "nothing")
}

pub fn remaining_gloogle_signature_variants_test() {
  let constant =
    "{\"type_name\":\"handler\",\"module_name\":\"app\",\"package_name\":\"sample\",\"version\":\"1.0.0\",\"json_signature\":{\"kind\":\"constant\",\"type\":{\"kind\":\"fn\",\"params\":[{\"kind\":\"tuple\",\"elements\":[{\"kind\":\"variable\",\"id\":0}]}],\"return\":{\"kind\":\"named\",\"name\":\"Nil\",\"parameters\":[]}}}}"
  let definition =
    "{\"type_name\":\"Maybe\",\"module_name\":\"maybe\",\"package_name\":\"sample\",\"version\":\"1.0.0\",\"json_signature\":{\"kind\":\"type-definition\",\"parameters\":1,\"constructors\":[{\"name\":\"Some\",\"parameters\":[{\"label\":null,\"type\":{\"kind\":\"variable\",\"id\":0}}]},{\"name\":\"None\",\"parameters\":[]}]}}"
  let body =
    "{\"exact-type-matches\":["
    <> constant
    <> ","
    <> definition
    <> "],\"exact-matches\":[],\"matches\":[],\"searches\":[],\"docs-searches\":[],\"module-searches\":[]}"
  let assert Ok(output) = global.decode_search_response(body, "maybe")

  assert string.contains(output, "const handler: fn(#(t0)) -> Nil")
  assert string.contains(output, "type Maybe(t0) {\n  Some(t0)\n  None\n}")
}

pub fn malformed_gloogle_fixture_is_error_test() {
  let assert Error("Gloogle returned an unexpected response") =
    global.decode_search_response("{}", "map")
}
