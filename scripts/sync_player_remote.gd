extends Node
@export var player_remote_scene: PackedScene
@export var player_local: PlayerLocal
var players_remote: Dictionary = {}

# method to use the HTTP connection as a stream 
#var http_client := HTTPClient.new()
#
#func _ready() -> void:
	#_setup_connection()
#
#func _setup_connection() -> void:
	#http_client.connect_to_host(FirebaseUrls.host_url)
	#
	#var status = http_client.get_status()
	#while status in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		#http_client.poll()
		#status = http_client.get_status()
	#
	#if status != HTTPClient.STATUS_CONNECTED:
		#printerr("Cannot connect to Firebase: %d" % status)
		#return
	#
	#http_client.request(
		#HTTPClient.METHOD_POST,
		#FirebaseUrls.get_players_url(),
		#["Accept: text/event-stream"]
	#)
	#
	#print("Connection success!")
#
#func _process(_delta: float) -> void:
	#_check_for_new_events()
#
#func _check_for_new_events() -> void:
	#http_client.poll()
	#if not http_client.has_response():
		#return
	#
	#var body = http_client.read_response_body_chunk()
	#if not body:
		#return
	#
	#var response = body.get_string_from_utf8()
	#var events = _parse_response_event_data(response)
	#
	#print(events)
#



# tcp method
func _ready() -> void:
	_start_listen()

func _start_listen() -> void:
	var tcp = await _setup_tcp_stream()
	var stream = await _setup_tls_stream(tcp)
	
	_start_sse_stream(stream)
	
	while true:
		var response = await _read_stream_response(stream)
		var events = _parse_response_event_data(response)
		for event in events:
			_handle_player_event(event)

func _handle_player_event(event: Dictionary):
	var path = event["path"] as String
	var data = event["data"]
	
	# two cases need to be considered- if the path is to a single slash or if it is to a player_id
	
	if path == "/":
		if data != null:
			for player_id in data.keys():
				_create_update_player(player_id, data[player_id])
		for player_id in players_remote.keys():
			if data == null or player_id not in data.keys():
				_delete_player(player_id)
	else:
		var path_parts = path.split("/")
		var player_id = path_parts[-1]
		if data != null:
			_create_update_player(player_id, data)
		else:
			_delete_player(player_id)
			
func _create_update_player(player_id: String, player_data: Dictionary) -> void:
	if player_id == str(player_local.player_id):
		return
	
	var player: PlayerRemote
	if player_id in players_remote:
		player = players_remote[player_id]
	else:
		player = player_remote_scene.instantiate()
		get_parent().add_child(player)
	
	player.update_from_event(player_data)
	players_remote[player_id] = player
	
func _delete_player(player_id: String) -> void:
	if player_id == str(player_local.player_id):
		return
	if player_id not in players_remote:
		return
	var player = players_remote[player_id] as PlayerRemote
	player.queue_free()

func _setup_tcp_stream() -> StreamPeerTCP:
	var tcp = StreamPeerTCP.new()
	
	var err_conn_tcp = tcp.connect_to_host(FirebaseUrls.host, 443)
	assert(err_conn_tcp == OK)
	tcp.poll()
	var tcp_status = tcp.get_status()
	while tcp_status != StreamPeerTCP.STATUS_CONNECTED:
		await get_tree().process_frame
		tcp.poll()
		tcp_status = tcp.get_status()
	
	return tcp

func _setup_tls_stream(tcp: StreamPeerTCP) -> StreamPeerTLS:
	var stream = StreamPeerTLS.new()
	
	var err_conn_stream = stream.connect_to_stream(tcp, FirebaseUrls.host)
	assert(err_conn_stream == OK) 
	
	stream.poll()
	var stream_status = stream.get_status()
	while stream_status != StreamPeerTLS.STATUS_CONNECTED:
		await get_tree().process_frame
		stream.poll()
		stream_status = stream.get_status()
	
	return stream

# in order to initialize an sse stream an initial request to open the stream is required
func _start_sse_stream(stream: StreamPeer) -> void:
	var url = FirebaseUrls.get_players_url()
	var request_line = "GET %s HTTP/1.1" % url
	var headers = [
		"Host: %s" % FirebaseUrls.host,
		"Accept: text/event-stream"
		]
	var request = ""
	request += request_line + "\n" # request line
	request += "\n".join(headers) + "\n" # headers
	request += "\n" # new line
	stream.put_data(request.to_ascii_buffer())

# after the sse stream is initalized, no morq requests are needed- just listening to new data\
func _read_stream_response(stream: StreamPeer) -> String:
	stream.poll()
	var available_bytes = stream.get_available_bytes()
	while available_bytes == 0:
		await get_tree().process_frame
		stream.poll()
		available_bytes = stream.get_available_bytes()
	
	return stream.get_string(available_bytes)

func _parse_response_event_data(response: String) -> Array:
	var response_parts = response.replace("\r", "").split("\n\n")
	var event_data: Array[Dictionary] = []
	for response_part in response_parts:
		var event = _parse_event_data(response_part)
		if event == null:
			continue
		if event.type != "put":
			continue
		event_data.append(event.data)
	return event_data

##same implementation for both HTTP requests and TCP Streams
class ServerSentEvent:
	var type: String # what kind of event received
	var data: Dictionary # event_data is a dictionary

const EVENT_TYPE_PREFIX = "event: "
const EVENT_DATA_PREFIX = "data: "

func _parse_event_data(response_part: String) -> ServerSentEvent:
	var event_lines = response_part.split("\n")
	if event_lines.size() != 2:
		return null
	var event_type_line = event_lines[0]
	if !event_type_line.begins_with(EVENT_TYPE_PREFIX):
		return null
	var event_data_line = event_lines[1]
	if !event_data_line.begins_with(EVENT_DATA_PREFIX):
		return null
	
	var event_type_str = event_type_line.substr(EVENT_TYPE_PREFIX.length())
	var event_data_str = event_data_line.substr(EVENT_DATA_PREFIX.length())
	
	#event_data_str will be in JSON format, thus we need to parse it
	var event_data_json = JSON.parse_string(event_data_str) 
	if event_data_json == null:
		event_data_json = {}
	
	var event = ServerSentEvent.new()
	event.type = event_type_str
	event.data = event_data_json
	
	return event



# create/update/delete player
