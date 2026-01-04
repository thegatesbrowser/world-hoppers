extends Resource
class_name ConnectionEvents

signal status_changed(status: Status)

enum Status { CONNECTING, FAILED_TO_CONNECT, CONNECTED, DISCONNECTED }


func status_changed_emit(status: Status) -> void:
	status_changed.emit(status)
