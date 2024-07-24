extends Node

#autoloaded functions to manage everything related to firebase urls

const host: String = "godot-multiplayer-5205f-default-rtdb.firebaseio.com"
const host_url = "https://" + host

func get_player_url(player_id) -> String:
	var path_player = "/players/%s.json" % player_id
	return host_url + path_player

func get_players_url() -> String:
	return host_url + "/players.json"
