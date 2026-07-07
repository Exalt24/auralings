extends Node

# Groq-backed creature loremaster. Given an Auraling's procedural traits, the LLM
# authors its identity (name, epithet, lore, ability). The SEED still drives the
# visuals, so the AI writes the soul while code draws the body. This is the
# AI-native hook: infinite hand-authored-feeling creatures at ~free compute.
#
# NOTE: for the shipped web build the key must live behind a serverless proxy
# (Vercel /api/summon) so it isn't exposed client-side. For desktop dev we read
# it from the gitignored secrets/ file. Endpoint is swappable for exactly that.

signal identity_ready(seed_val: int, identity: Dictionary)

const GROQ_ENDPOINT := "https://api.groq.com/openai/v1/chat/completions"
const PROXY_ENDPOINT := "/api/summon"  # same-origin Vercel serverless proxy (web build)
const MODEL := "llama-3.3-70b-versatile"

var _http: HTTPRequest
var _key := ""
var _is_web := false
var _pending_seed := 0

func _ready() -> void:
	_is_web = OS.has_feature("web")
	_http = HTTPRequest.new()
	_http.timeout = 12.0  # never leave the summon button stuck on a hung network
	add_child(_http)
	_http.request_completed.connect(_on_done)
	# desktop reads the key from the gitignored secret; the web build never sees a
	# key at all (it goes through the proxy, which holds the key server-side).
	if not _is_web:
		var f := FileAccess.open("res://secrets/groq_key.txt", FileAccess.READ)
		if f:
			_key = f.get_as_text().strip_edges()

func has_key() -> bool:
	# on web we always route through the proxy, so identity is always available
	return _is_web or _key != ""

func request_identity(c: Dictionary) -> void:
	_http.cancel_request()  # a newer summon supersedes any in-flight request
	_pending_seed = int(c["seed"])
	if _is_web:
		# hand the traits to the proxy; it builds the prompt + injects the key.
		# Godot's HTTPRequest needs an ABSOLUTE url even on web, so resolve the
		# page origin at runtime and prepend it to the same-origin proxy path.
		var payload := {
			"element": c["element"], "archetype": c["archetype"],
			"hp": int(c["hp"]), "atk": int(c["atk"]), "name": c["name"],
		}
		var origin := ""
		var loc = JavaScriptBridge.eval("window.location.origin", true)
		if typeof(loc) == TYPE_STRING and String(loc).begins_with("http"):
			origin = String(loc)
		var headers := ["Content-Type: application/json"]
		var err := _http.request(origin + PROXY_ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
		if err != OK:
			identity_ready.emit(_pending_seed, {})
		return

	var sys := "You are the loremaster of Auralings: tiny, cute elemental spirit-creatures. Given a creature's traits, invent its identity. Keep it whimsical and warm. Return ONLY JSON with keys: name (one invented cute word, 2 syllables), title (a 2-3 word epithet), lore (one vivid sentence, max 16 words), ability_name (2 words), ability_desc (one short sentence, max 12 words)."
	var usr := "element: %s\narchetype: %s\nhp: %d\natk: %d\nseed-hint-name: %s" % [c["element"], c["archetype"], int(c["hp"]), int(c["atk"]), c["name"]]
	var body := {
		"model": MODEL,
		"messages": [
			{"role": "system", "content": sys},
			{"role": "user", "content": usr},
		],
		"response_format": {"type": "json_object"},
		"temperature": 1.1,
		"max_tokens": 220,
	}
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + _key]
	var err := _http.request(GROQ_ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		identity_ready.emit(_pending_seed, {})

func _on_done(_result: int, code: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if code != 200:
		identity_ready.emit(_pending_seed, {})
		return
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		identity_ready.emit(_pending_seed, {})
		return
	# web proxy returns the identity dict directly; Groq wraps it in choices[].message.content
	var identity = parsed
	if not _is_web:
		if not parsed.has("choices"):
			identity_ready.emit(_pending_seed, {})
			return
		identity = JSON.parse_string(parsed["choices"][0]["message"]["content"])
		if typeof(identity) != TYPE_DICTIONARY:
			identity = {}
	identity_ready.emit(_pending_seed, identity)
