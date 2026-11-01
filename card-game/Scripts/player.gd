extends CharacterBody2D

enum State {
	IDLE,
	UP,
	DOWN,
	LEFT,
	RIGHT
}

@export_category("Stats")
@export var speed: int = 400
@export var talk_portrait: Texture2D        # shown in dialogue instead of the map sprite

var state: State = State.IDLE
var move_direction: Vector2 = Vector2(0,0)
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]

func _physics_process(delta: float) -> void:
	movement_loop()
	
	
func movement_loop():
	move_direction.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	move_direction.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	var motion: Vector2 = move_direction.normalized() * speed
	set_velocity(motion)
	move_and_slide()
	
	var up_pressed = false
	var down_pressed = false
	var left_pressed = false
	var right_pressed = false
	
	if motion != Vector2.ZERO:
		animation_tree.active = true
			
		if motion.y <-0.01:
			state = State.UP
			up_pressed = true
		elif motion.y >0.01:
			state = State.DOWN
			down_pressed = true
		elif motion.x <-0.01:
			left_pressed = true
			state = State.LEFT
		elif motion.x > 0.01:
			state = State.RIGHT
			right_pressed = true
	else:
		state = State.IDLE
		up_pressed = false
		down_pressed = false
		left_pressed = false
		right_pressed = false
	update_animation()


func update_animation() -> void:
	match state:
		State.IDLE:
			animation_tree.active = false
			pass
		State.RIGHT:
			animation_playback.travel("player_right")
		State.LEFT:
			animation_playback.travel("player_left")
		State.UP:
			animation_playback.travel("player_up")
		State.DOWN:
			animation_playback.travel("player_forward")
			
			
