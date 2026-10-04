extends Node
class_name WebRunDiagnostics

## Small, web-only lifecycle probe. It intentionally owns diagnostics rather
## than recovery: recovery must consume a known-safe room boundary first.
const STORAGE_KEY := "tiny_demons_web_lifecycle_v1"
const MAX_EVENTS := 32

var session_id := ""
var startup_count := 0
var last_checkpoint_at := 0.0
var last_checkpoint_room := ""
var _callback: JavaScriptObject = null


func configure(root: Object) -> void:
	if not OS.has_feature("web"):
		return
	session_id = "%s-%s" % [Time.get_unix_time_from_system(), randi()]
	var previous := _read_events()
	startup_count = int(previous.get("startup_count", 0)) + 1
	var previous_events: Array = previous.get("events", []) as Array
	for index in range(previous_events.size() - 1, -1, -1):
		var previous_event: Variant = previous_events[index]
		if previous_event is Dictionary and str((previous_event as Dictionary).get("event", "")) == "checkpoint":
			last_checkpoint_at = float((previous_event as Dictionary).get("at", 0.0))
			last_checkpoint_room = str((previous_event as Dictionary).get("room", ""))
			break
	_callback = JavaScriptBridge.create_callback(func(args: Array) -> void:
		var event_name := str(args[0]) if not args.is_empty() else "unknown"
		record(event_name, root)
	)
	JavaScriptBridge.eval("""
		(function(cb) {
			window.__tdWebLifecycle = cb;
			if (window.__tdWebLifecycleListenersInstalled) {
				return;
			}
			var emit = function(name) {
				if (window.__tdWebLifecycle) window.__tdWebLifecycle(name);
			};
			window.addEventListener('pagehide', function() { emit('pagehide'); });
			window.addEventListener('pageshow', function() { emit('pageshow'); });
			document.addEventListener('visibilitychange', function() { emit('visibility:' + document.visibilityState); });
			window.addEventListener('beforeunload', function() { emit('beforeunload'); });
			var bindCanvas = function() {
				var canvas = document.querySelector('canvas');
				if (!canvas || canvas.__tdWebLifecycleBound) return;
				canvas.__tdWebLifecycleBound = true;
				canvas.addEventListener('webglcontextlost', function() { emit('webgl_context_lost'); });
				canvas.addEventListener('webglcontextrestored', function() { emit('webgl_context_restored'); });
			};
			bindCanvas();
			window.setTimeout(bindCanvas, 0);
			window.setTimeout(bindCanvas, 1000);
			window.__tdWebLifecycleListenersInstalled = true;
		})(%s);
	""" % str(_callback))
	if OS.is_debug_build():
		JavaScriptBridge.eval("""
			window.__tdReadLifecycle = function() { return localStorage.getItem(%s); };
			window.__tdClearLifecycle = function() { localStorage.removeItem(%s); };
		""" % [JSON.stringify(STORAGE_KEY), JSON.stringify(STORAGE_KEY)])
	record("startup", root)


func record(event_name: String, root: Object = null) -> void:
	if not OS.has_feature("web"):
		return
	var data := _read_events()
	var events: Array = data.get("events", []) as Array
	var viewport := Vector2i.ZERO
	var game_version := ""
	if root != null:
		var display := root.get("display_controller") as DisplayController
		if display != null:
			viewport = display.view_size_value()
		var screens := root.get("screen_state_controller") as ScreenStateController
		if screens != null:
			game_version = str(screens.GAME_VERSION)
	var event := {
		"event": event_name,
		"at": Time.get_unix_time_from_system(),
		"session": session_id,
		"room": String(root.get("current_room_id")) if root != null else "",
		"run": str(root.get("run_state").run_id) if root != null and root.get("run_state") != null else "",
		"game_version": game_version,
		"viewport": {"width": viewport.x, "height": viewport.y},
		"orientation": "portrait" if viewport.y > viewport.x else "landscape",
		"last_checkpoint_at": last_checkpoint_at,
		"last_checkpoint_room": last_checkpoint_room,
		"user_agent": str(JavaScriptBridge.eval("navigator.userAgent || ''")).left(160),
	}
	events.append(event)
	while events.size() > MAX_EVENTS:
		events.pop_front()
	data["startup_count"] = startup_count
	data["events"] = events
	_web_set(JSON.stringify(data))
	print("[web-lifecycle] ", JSON.stringify(event))


func record_checkpoint(root: Object) -> void:
	last_checkpoint_at = Time.get_unix_time_from_system()
	last_checkpoint_room = String(root.get("current_room_id")) if root != null else ""
	record("checkpoint", root)


func read_events() -> Dictionary:
	return _read_events()


func clear_events() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.removeItem(%s)" % JSON.stringify(STORAGE_KEY))


func _read_events() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw: Variant = JavaScriptBridge.eval("localStorage.getItem(%s)" % JSON.stringify(STORAGE_KEY))
	if raw == null or str(raw).is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(str(raw))
	return parsed as Dictionary if parsed is Dictionary else {}


func _web_set(value: String) -> void:
	JavaScriptBridge.eval("localStorage.setItem(%s, %s)" % [JSON.stringify(STORAGE_KEY), JSON.stringify(value)])
