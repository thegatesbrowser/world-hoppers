@icon("res://addons/mod_packer/cloud_download_500dp_E3E3E3_FILL0_wght400_GRAD0_opsz48.svg")
extends Node
class_name ModDownloader

var zips_url := "http://127.0.0.1:8000/zips"
var download_path_fmt := "http://127.0.0.1:8000/download/%s"

@onready var http_req := HTTPRequest.new()
var _threads := []
var _completed := []
var _mutex := Mutex.new()

func _ready() -> void:
	add_child(http_req)
	http_req.request_completed.connect(_on_zips_response)
	http_req.request(zips_url)

func _process(_delta: float) -> void:
	if _mutex.try_lock():
		while _completed.size() > 0:
			var path := _completed.pop_front()
			print("Saved:", path)
			print("=== LOADING PACK ===")
			var ok := ProjectSettings.load_resource_pack(path)
			print("Pack loaded:", ok)
		_mutex.unlock()

func _on_zips_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("Failed to fetch zips: %d" % response_code)
		return
	var j := JSON.parse_string(body.get_string_from_utf8())
	if typeof(j) == TYPE_DICTIONARY and j.has("zips"):
		for z in j.zips:
			var id := str(z.id)
			var th := Thread.new()
			_threads.append(th)
			th.start(Callable(self, "_download_thread").bind(id))

# ...existing code...
func _download_thread(file_id: String) -> void:
	var client := HTTPClient.new()
	if client.connect_to_host("127.0.0.1", 8000) != OK:
		print("Failed to connect")
		return

	while client.get_status() == HTTPClient.STATUS_CONNECTING:
		client.poll()
		OS.delay_msec(10)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		print("Connection failed")
		return

	var url := "/download/%s" % file_id
	var headers := PackedStringArray()
	client.request(HTTPClient.METHOD_GET, url, headers)

	var out_path := "user://%s.zip" % file_id
	var buffer := PackedByteArray()
	var content_length := -1
	var headers_read := false

	while true:
		client.poll()
		var status := client.get_status()

		if status == HTTPClient.STATUS_BODY:
			# Read headers once to get Content-Length
			if not headers_read:
				var hdrs = client.get_response_headers_as_dictionary()
				print("Headers: ", hdrs)
				
				if hdrs.has("content-length"):
					content_length = int(hdrs["content-length"])
				elif hdrs.has("Content-Length"):
					content_length = int(hdrs["Content-Length"])
				
				print("Expected size: %d bytes" % content_length)
				headers_read = true

			var chunk := client.read_response_body_chunk()
			if chunk.size() > 0:
				buffer.append_array(chunk)
				print("Received %d bytes, total: %d/%d" % [chunk.size(), buffer.size(), content_length])

			if content_length > 0 and buffer.size() >= content_length:
				print("Download complete")
				break

		elif status == HTTPClient.STATUS_DISCONNECTED:
			print("Disconnected")
			break

		OS.delay_msec(5)

	client.close()

	if buffer.size() > 0:
		var file := FileAccess.open(out_path, FileAccess.ModeFlags.WRITE)
		if file:
			file.store_buffer(buffer)
			file = null
			print("Saved %s: %d bytes" % [file_id, buffer.size()])
			_mutex.lock()
			_completed.append(out_path)
			_mutex.unlock()
		else:
			print("Failed to open file:", out_path)
	else:
		print("No data received for %s" % file_id)
