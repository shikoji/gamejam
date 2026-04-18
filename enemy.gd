extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck
@onready var player_check: RayCast2D = $PlayerCheck
@onready var attack_check: RayCast2D = $AttackCheck
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var hitbox: Area2D = $hitbox
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

@export var gravity := 900.0
@export var speed := 50.0
@export var dash_speed := 180.0
@export var health := 3

var direction := 1
var can_damage := true

enum State { PATROL, DASH, ATTACK }
var state = State.PATROL

var can_take_damage := true
var is_hurt := false
var is_attacking := false

func _ready() -> void:
	# 🔥 CONECTA SINAIS
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	check_environment()

	if is_hurt:
		move_and_slide()
		return

	match state:
		State.PATROL:
			patrol()
		State.DASH:
			dash()
		State.ATTACK:
			attack()

	move_and_slide()


func check_environment():
	if state == State.DASH or state == State.ATTACK:
		return

	if wall_check.is_colliding() or not floor_check.is_colliding():
		flip()


func patrol():
	attack_hitbox.monitoring = false
	anim.play("walk")
	velocity.x = speed * direction

	if player_check.is_colliding():
		state = State.DASH


func dash():
	attack_hitbox.monitoring = false
	anim.play("dash")
	velocity.x = dash_speed * direction

	if attack_check.is_colliding():
		state = State.ATTACK

	if not player_check.is_colliding():
		state = State.PATROL


func attack():
	if not is_attacking:
		is_attacking = true
		anim.play("attacking")

	velocity.x = 0
	attack_hitbox.monitoring = true

	if can_damage and attack_hitbox.has_overlapping_bodies():
		for body in attack_hitbox.get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_damage(1)
				can_damage = false
				await get_tree().create_timer(2).timeout
				can_damage = true
				break

	if not attack_check.is_colliding():
		state = State.PATROL
		is_attacking = false
		attack_hitbox.monitoring = false


func flip():
	direction *= -1
	anim.flip_h = direction < 0

	wall_check.scale.x *= -1
	floor_check.scale.x *= -1
	player_check.scale.x *= -1
	attack_check.scale.x *= -1
	attack_hitbox.scale.x *= -1

	
func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		take_damage(1)

		
func take_damage(amount: int) -> void:
	if not can_take_damage:
		return

	can_take_damage = false
	is_hurt = true

	health -= amount
	velocity.x = 0
	
	state = State.PATROL
	is_attacking = false
	attack_hitbox.monitoring = false

	anim.play("hurt")
	print("❌ Enemy levou dano! HP: ", health)

	if health <= 0:
		die()
		return

	await anim.animation_finished
	
	await get_tree().create_timer(0.3).timeout

	is_hurt = false

	await get_tree().create_timer(0.5).timeout
	can_take_damage = true

func die() -> void:
	print("💀 Enemy morrendo...")
	anim.play("death")
	set_physics_process(false)
	hitbox.queue_free()
	collision_shape_2d.queue_free()
	await anim.animation_finished
	queue_free()
