@tool
class_name TGProjectPublisher
extends Node

const DEFAULT_API_BASE_URL = "https://app.thegates.io"
const CREATE_PROJECT_API_PATH = "/api/create_project"
const PUBLISH_API_PATH = "/api/publish_project"
const GET_PUBLISHED_API_PATH = "/api/get_published_project"
const DELETE_PROJECT_API_PATH = "/api/delete_project"

const FORM_FIELD_TOKEN = "token"
const FORM_FIELD_FILES = "files"

const TOKEN_HEADER_HINT = "# TheGates project token for publishing. Keep this file private."


func load_token(settings: TGExportSettings) -> String:
	var token := get_token(settings)
	if token.is_empty():
		token = await ensure_project_token(settings)
	return token


func ensure_project_token(settings: TGExportSettings) -> String:
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray([
		"Accept: application/json",
		"Content-Type: application/json"
	])
	var payload := {
		"project_name": ProjectSettings.get_setting("application/config/name")
	}
	var json_payload := JSON.stringify(payload)
	var error := request.request(get_create_endpoint(), headers, HTTPClient.METHOD_POST, json_payload)
	if error != OK:
		printerr("Create project request failed to start: %s" % error)
		request.queue_free()
		return ""
	
	var completed = await request.request_completed
	request.queue_free()
	var result: int = completed[0]
	var response_code: int = completed[1]
	var _headers: PackedStringArray = completed[2]
	var response_body: PackedByteArray = completed[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Create project request failed: result=%s" % result)
		return ""
	
	if response_code != 201 and response_code != 200:
		printerr("Create project request returned HTTP %s" % response_code)
		return ""
	
	var text := response_body.get_string_from_utf8()
	if text.is_empty():
		return ""
	
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		printerr("Failed to parse create project response: %s" % json.get_error_message())
		printerr(text)
		return ""
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	var response: Dictionary = data
	var token := str(response.get("token", ""))
	if token.is_empty():
		printerr("Create project response missing token")
		return ""
	save_token(settings, token)
	return token


func get_publish_endpoint() -> String:
	return DEFAULT_API_BASE_URL + PUBLISH_API_PATH


func get_create_endpoint() -> String:
	return DEFAULT_API_BASE_URL + CREATE_PROJECT_API_PATH


func get_check_endpoint() -> String:
	return DEFAULT_API_BASE_URL + GET_PUBLISHED_API_PATH


func get_delete_endpoint() -> String:
	return DEFAULT_API_BASE_URL + DELETE_PROJECT_API_PATH


func get_token(settings: TGExportSettings) -> String:
	var path := settings.get_token_path()
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Failed to open token file: %s" % path)
		return ""
	var contents := file.get_as_text()
	file.close()
	var lines := contents.split("\n", false)
	if lines.is_empty():
		return ""
	if lines[0].begins_with("#"):
		lines.remove_at(0)
	var token := "\n".join(lines).strip_edges()
	return token


func save_token(settings: TGExportSettings, token: String) -> void:
	var path := settings.get_token_path()
	var dir_path := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Failed to write token file: %s" % path)
		return
	file.store_string(TOKEN_HEADER_HINT + "\n" + token)
	file.close()
	
	TGExportSettingsBackup.save_token(settings)


func publish(settings: TGExportSettings) -> String:
	if not is_valid(settings):
		return ""
	
	var token := await load_token(settings)
	if token.is_empty():
		return ""
	
	var form_data := {
		FORM_FIELD_TOKEN: token,
	}
	
	var file_payloads: Array = []
	
	var gate_payload := build_file_payload(settings.get_gate_path())
	if not gate_payload.is_empty():
		file_payloads.append(gate_payload)
	
	var pack_payload := build_file_payload(settings.get_pack_path())
	if not pack_payload.is_empty():
		file_payloads.append(pack_payload)
	
	var icon_payload := build_file_payload(settings.get_icon_path())
	if not icon_payload.is_empty():
		file_payloads.append(icon_payload)
	
	var image_payload := build_file_payload(settings.get_image_path())
	if not image_payload.is_empty():
		file_payloads.append(image_payload)
	
	if file_payloads.is_empty():
		printerr("Publishing aborted: no export artifacts found")
		return ""
	
	var boundary := "----TheGatesBoundary%d" % Time.get_ticks_usec()
	var body := build_multipart_body(boundary, form_data, file_payloads)
	var headers := PackedStringArray([
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
		"Accept: application/json"
	])
	
	var request := HTTPRequest.new()
	add_child(request)
	
	var error := request.request_raw(get_publish_endpoint(), headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		printerr("Publish request failed to start: %s" % error)
		request.queue_free()
		return ""
	
	var completed = await request.request_completed
	request.queue_free()
	
	var result: int = completed[0]
	var response_code: int = completed[1]
	var _headers: PackedStringArray = completed[2]
	var response_body: PackedByteArray = completed[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Publish request failed: result=%s" % result)
		return ""
	
	return process_publish_response(result, response_code, response_body)


func is_valid(settings: TGExportSettings) -> bool:
	if not FileAccess.file_exists(settings.get_pack_path()):
		printerr("Missing exported pack: %s" % settings.get_pack_path())
		return false
	
	if not FileAccess.file_exists(settings.get_gate_path()):
		printerr("Missing gate metadata: %s" % settings.get_gate_path())
		return false
	
	return true


func build_file_payload(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Failed to open file for publishing: %s" % path)
		return {}
	
	var data := file.get_buffer(file.get_length())
	file.close()
	
	return {
		"name": FORM_FIELD_FILES,
		"filename": path.get_file(),
		"body": data,
		"content_type": guess_mime_type(path.get_file())
	}


func build_multipart_body(boundary: String, form: Dictionary, files: Array) -> PackedByteArray:
	var body := PackedByteArray()
	
	for key in form.keys():
		var value = form[key]
		if value == null:
			continue
		body.append_array(form_field_segment(boundary, key, str(value)))
	
	for file_dict in files:
		body.append_array(file_field_segment(boundary, file_dict))
	
	body.append_array(multipart_closing(boundary))
	return body


func form_field_segment(boundary: String, key: String, value: String) -> PackedByteArray:
	var segment = "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, key, value]
	return segment.to_utf8_buffer()


func file_field_segment(boundary: String, file_dict: Dictionary) -> PackedByteArray:
	var filename: String = file_dict.get("filename", "file")
	var name: String = file_dict.get("name", FORM_FIELD_FILES)
	var data: PackedByteArray = file_dict.get("body", PackedByteArray())
	var content_type: String = file_dict.get("content_type", "application/octet-stream")
	
	var header = "--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [boundary, name, filename, content_type]
	var footer = "\r\n"
	
	var segment := PackedByteArray()
	segment.append_array(header.to_utf8_buffer())
	segment.append_array(data)
	segment.append_array(footer.to_utf8_buffer())
	return segment


func multipart_closing(boundary: String) -> PackedByteArray:
	return ("--%s--\r\n" % boundary).to_utf8_buffer()


func guess_mime_type(filename: String) -> String:
	var extension := filename.get_extension().to_lower()
	match extension:
		"png":
			return "image/png"
		"jpg", "jpeg":
			return "image/jpeg"
		"webp":
			return "image/webp"
		"bmp":
			return "image/bmp"
		"svg":
			return "image/svg+xml"
		"zip":
			return "application/zip"
		"gate":
			return "application/octet-stream"
		_:
			return "application/octet-stream"


func process_publish_response(result: int, response_code: int, body: PackedByteArray) -> String:
	var text := body.get_string_from_utf8()
	if text.is_empty():
		return ""
	
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error == OK:
		var data = json.data
		if typeof(data) == TYPE_DICTIONARY:
			var response: Dictionary = data
			var url_value := ""
			if response.has("url") and typeof(response["url"]) == TYPE_STRING:
				url_value = str(response["url"])
			if not url_value.is_empty():
				print("Successfully published the project")
				return url_value
			# Fallthrough: print body for diagnostics if structure unexpected
			print(text)
	else:
		printerr("Failed to parse publish response: %s" % json.get_error_message())
		printerr(text)
	
	if response_code != 201 and response_code != 200:
		printerr("Publishing failed with HTTP status %s" % response_code)
	
	return ""


func check_project(settings: TGExportSettings) -> String:
	var token := await load_token(settings)
	if token.is_empty():
		return ""

	var request_url := "%s?%s=%s" % [get_check_endpoint(), FORM_FIELD_TOKEN, token.uri_encode()]
	var headers := PackedStringArray(["Accept: application/json"])
	
	var request := HTTPRequest.new()
	add_child(request)
	
	var error := request.request(request_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		printerr("Check project request failed to start: %s" % error)
		request.queue_free()
		return ""
	
	var completed = await request.request_completed
	request.queue_free()
	
	var result: int = completed[0]
	var response_code: int = completed[1]
	var _headers: PackedStringArray = completed[2]
	var body: PackedByteArray = completed[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Check project request failed: result=%s" % result)
		return ""
	
	if response_code == 404:
		return ""
	
	if response_code != 200:
		printerr("Check project request returned HTTP %s" % response_code)
		return ""
	
	var text := body.get_string_from_utf8()
	if text.is_empty():
		return ""
	
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		printerr("Failed to parse check project response: %s" % json.get_error_message())
		printerr(text)
		return ""
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	
	var response: Dictionary = data
	var url := response.get("url", "")
	if typeof(url) == TYPE_STRING:
		return str(url)
	
	return ""


func delete_project(settings: TGExportSettings) -> bool:
	var token := await load_token(settings)
	if token.is_empty():
		return false
	
	var headers := PackedStringArray([
		"Content-Type: application/x-www-form-urlencoded",
		"Accept: application/json"
	])
	var body := "token=%s" % token.uri_encode()
	
	var request := HTTPRequest.new()
	add_child(request)
	
	var error := request.request(get_delete_endpoint(), headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		printerr("Delete project request failed to start: %s" % error)
		request.queue_free()
		return false
	
	var completed = await request.request_completed
	request.queue_free()
	
	var result: int = completed[0]
	var response_code: int = completed[1]
	var _headers: PackedStringArray = completed[2]
	var response_body: PackedByteArray = completed[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Delete project request failed: result=%s" % result)
		return false
	
	var text := response_body.get_string_from_utf8()
	if text.is_empty():
		var success := response_code == 200
		if success:
			print("Successfully deleted the project")
		return success
	
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		printerr("Failed to parse delete response: %s" % json.get_error_message())
		printerr(text)
		return false
	
	var response: Dictionary = json.data
	var status := str(response.get("status", ""))
	var code := str(response.get("code", ""))
	if response_code == 200 and status == "ok" and code == "deleted":
		print("Successfully deleted the project")
		return true
	
	var message := str(response.get("message", ""))
	var detail := str(response.get("detail", ""))
	var error_text := "Delete project failed (%s)" % code if message.is_empty() else "Delete project failed (%s): %s" % [code, message]
	printerr(error_text)
	if not detail.is_empty():
		printerr(detail)
	
	return false
