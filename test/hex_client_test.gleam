import gleam/option.{None, Some}
import tools/hex_client

pub fn package_fixture_decodes_test() {
  let body =
    "[{\"name\":\"gleam_json\",\"latest_version\":\"3.1.0\",\"meta\":{\"description\":\"Work with JSON\",\"links\":{\"Repository\":\"https://github.com/gleam-lang/json\"}},\"docs_html_url\":\"https://gleam-json.hexdocs.pm/\",\"html_url\":\"https://hex.pm/packages/gleam_json\"},{\"name\":\"minimal\"}]"
  let assert Ok([first, second]) = hex_client.decode_package_search(body)
  assert first.name == "gleam_json"
  assert first.version == "3.1.0"
  assert first.docs_url == Some("https://gleam-json.hexdocs.pm/")
  assert first.repository_url == Some("https://github.com/gleam-lang/json")
  assert second.version == "unknown"
  assert second.docs_url == None
}

pub fn release_fixture_decodes_test() {
  let body =
    "{\"releases\":[{\"version\":\"3.1.0\",\"inserted_at\":\"2025-11-08T10:35:25Z\",\"retirement\":null},{\"version\":\"2.0.0\",\"retirement\":{\"reason\":\"invalid\"}}]}"
  let assert Ok([current, retired]) = hex_client.decode_releases(body)
  assert current.retired == False
  assert retired.retired == True
  assert retired.inserted_at == "unknown"
}

pub fn malformed_hex_fixture_is_error_test() {
  let assert Error(_) = hex_client.decode_package_search("{\"not\":\"a list\"}")
  let assert Error(_) = hex_client.decode_releases("[]")
}
