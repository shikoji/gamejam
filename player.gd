extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox: Area2D = $hitbox
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var mat: ShaderMaterial = animated_sprite.material

var wall_jump_velocity = Vector2(-500, -600)
var is_wall_sliding = false

var facing_direction := 1  
@export var health := 5
var can_take_damage := true
var is_hurt := false

var is_dashing := false
var dash_time := 0.15
var dash_timer := 0.0

var is_attacking := false
var can_attack := true
var last_direction := 1

func _ready() -> void:
	if not attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered):
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	print("✅ Player ready - HP: ", health)

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("left", "right")

	if not is_on_floor():
		velocity += get_gravity() * delta / 2
		
	if is_hurt:
		move_and_slide()
		return

	update_facing_direction(direction)

	if Input.is_action_just_pressed("attack") and not is_dashing and can_attack:
		start_attack()

	if is_on_wall() and not is_on_floor() and direction != 0:
		velocity.y = min(velocity.y, 200)
		animated_sprite.play("wallslide")
		animated_sprite.flip_h = facing_direction < 0

		if Input.is_action_just_pressed("jump"):
			velocity.x = get_wall_normal().x * gamemanager.player_SPEED * 2
			velocity.y = gamemanager.player_JUMP_VELOCITY
			animated_sprite.play("jump_up")

		move_and_slide()
		return

	if Input.is_action_just_pressed("dash") and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		animated_sprite.play("dash")
		velocity.x = facing_direction * gamemanager.player_SPEED * 4

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

	if not is_dashing:
		if abs(velocity.x) <= gamemanager.player_SPEED:
			if direction:
				last_direction = sign(direction)
				if not is_attacking:
					animated_sprite.play("run")
				animated_sprite.flip_h = facing_direction < 0
				velocity.x = direction * gamemanager.player_SPEED
			else:
				if not is_attacking:
					animated_sprite.play("idle")
				velocity.x = move_toward(velocity.x, 0, gamemanager.player_SPEED)
		else:
			velocity.x = move_toward(velocity.x, direction * gamemanager.player_SPEED, 10)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		if not is_attacking:
			animated_sprite.play("jump_up")
		velocity.y = gamemanager.player_JUMP_VELOCITY
	
	if not is_on_floor():
		if velocity.y < -10:
			if not is_attacking:
				animated_sprite.play("jump_up")
		elif abs(velocity.y) <= 10:
			if not is_attacking:
				animated_sprite.play("jump_top")
		else:
			if not is_attacking:
				animated_sprite.play("jump_down")
				
	move_and_slide()


func update_facing_direction(direction: float) -> void:
	if direction != 0:
		facing_direction = sign(direction)
		last_direction = facing_direction
	
	attack_hitbox.scale.x = facing_direction


func start_attack() -> void:
	if not can_attack or is_attacking:
		return
	
	is_attacking = true
	can_attack = false
	
	animated_sprite.play("attacking_sword")
	attack_hitbox.monitoring = true

	await animated_sprite.animation_finished
	
	attack_hitbox.monitoring = false
	is_attacking = false
	can_attack = true


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and is_attacking:
		print("💥 Golpe acertou em: ", body.name)
		body.take_damage(1)


func take_damage(amount: int) -> void:
	if not can_take_damage or is_attacking:  
		return

	can_take_damage = false
	is_hurt = true

	health -= amount
	velocity.x = 0

	animated_sprite.play("hurt")
	
	if mat:
		mat.set_shader_parameter("active", true)

	print("❌ Player levou ", amount, " de dano. HP: ", health)

	if health <= 0:
		die()
		return
		
	await get_tree().create_timer(0.15).timeout

	if mat:
		mat.set_shader_parameter("active", false)

	await get_tree().create_timer(0.3).timeout

	is_hurt = false

	await get_tree().create_timer(0.5).timeout
	can_take_damage = true


func die() -> void:
	print("💀 Player morrendo...")
	animated_sprite.play("death")
	set_physics_process(false)
	hitbox.queue_free()
	collision_shape_2d.queue_free()
	await animated_sprite.animation_finished
	queue_free()


func _on_hitbox_body_entered(body):
	if body.is_in_group("enemy"):
		take_damage(1)
