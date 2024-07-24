extends HTTPRequest

@export var player: PlayerLocal
var is_request_pending: bool = false
var prev_player_data_json: String

# modifies ready so that it interacts with PUT and DELETE methods properly
func _ready() -> void:
	get_tree().set_auto_accept_quit(false) 
	request_completed.connect(_on_request_completed)

# notification for quitting logic
func _notification(what) -> void: 
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_delete_local_player()

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	if result != RESULT_SUCCESS:
		printerr("request failed with response code %d" % response_code)
	is_request_pending = false

# checks if current request is pending, then sends to the rtdb local player info
func _process(_delta: float) -> void:
	if !is_request_pending:
		_send_local_player()

# PUT request handling
func _send_local_player() -> void:
	var player_data = {
		"id": player.player_id,
		"position_x": player.global_position.x,
		"position_y": player.global_position.y, 
		"color": player.player_color.to_html(false)
	}
	var player_data_json = JSON.stringify(player_data)
	if player_data_json == prev_player_data_json:
		return
	var url = FirebaseUrls.get_player_url(player.player_id)
	is_request_pending = true
	request(url, [], HTTPClient.METHOD_PUT, player_data_json)

# DELETE request handling
func _delete_local_player() -> void:
	var url = FirebaseUrls.get_player_url(player.player_id)
	cancel_request()
	request(url, [], HTTPClient.METHOD_DELETE, "")
	await request_completed
	get_tree().quit()
