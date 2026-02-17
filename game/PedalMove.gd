extends Control

@onready var left_ticker: Panel = $Left/Ticker
@onready var right_ticker: Panel = $Right/Ticker
@onready var left_overlay: Panel = $Left/Overlay
@onready var right_overlay: Panel = $Right/Overlay

const TICKER_TOP_Y: float = 16.0
const TICKER_BOTTOM_Y: float = 402
const CYCLE_DURATION: float = 1.0
const FADE_DURATION: float = 0.25

var left_active: bool = true

var tween: Tween

func _ready() -> void:
	left_overlay.visible = true
	left_overlay.modulate.a = 0.0
	right_overlay.visible = true
	right_overlay.modulate.a = 1.0
	left_ticker.position.y = TICKER_TOP_Y
	right_ticker.position.y = TICKER_BOTTOM_Y
	_run_cycle()

func _run_cycle() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(left_ticker, "position:y", TICKER_BOTTOM_Y, CYCLE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(right_ticker, "position:y", TICKER_TOP_Y, CYCLE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	tween.set_parallel(false)
	tween.tween_callback(_swap_and_continue)

func _swap_and_continue() -> void:
	left_active = false
	left_ticker.position.y = TICKER_BOTTOM_Y
	right_ticker.position.y = TICKER_TOP_Y

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(left_ticker, "position:y", TICKER_TOP_Y, CYCLE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(right_ticker, "position:y", TICKER_BOTTOM_Y, CYCLE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# fade left in, right out
	tween.tween_property(left_overlay, "modulate:a", 1.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(right_overlay, "modulate:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	tween.set_parallel(false)
	tween.tween_callback(_reset_and_loop)

func _reset_and_loop() -> void:
	left_active = true
	left_ticker.position.y = TICKER_TOP_Y
	right_ticker.position.y = TICKER_BOTTOM_Y

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(left_ticker, "position:y", TICKER_BOTTOM_Y, CYCLE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(right_ticker, "position:y", TICKER_TOP_Y, CYCLE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# fade left out, right in
	tween.tween_property(left_overlay, "modulate:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(right_overlay, "modulate:a", 1.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	tween.set_parallel(false)
	tween.tween_callback(_swap_and_continue)

func get_left_ticker_y() -> float:
	return left_ticker.position.y

func get_right_ticker_y() -> float:
	return right_ticker.position.y

func is_left_active() -> bool:
	return left_active
