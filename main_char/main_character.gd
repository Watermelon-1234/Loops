extends CharacterBody2D

# 物理參數設定
const SPEED = 50.0
const JUMP_VELOCITY = -200.0
const GRAVITY = 980.0
const ROOM_WIDTH = 192

# 狀態控制
enum State { READY, WALK, IDLE, JUMP, DAMAGED, DIE }
var current_state: State = State.IDLE # 初始狀態改為 IDLE，配合 ready 的等待
var current_room_index: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var tilemap_layer: TileMapLayer = $"../Terrain" 

#func debug_log(var_name: String, value: Variant) -> void:
	## [color=cyan] 可以讓變數名稱顯示成青色，方便閱讀
	#print_rich("[color=cyan]【%s】[/color] -> %s (型別: %s)" % [var_name, str(value), type_string(typeof(value))])

## 萬用 Debug 輸出函數：可傳入任意數量的變數
func debug(args: Array = []) -> void:
	# 利用 var_to_str 或 str 把所有變數串接起來，並用 " | " 分隔
	var output_segments: Array[String] = []
	for arg in args:
		# 如果是 Vector2、Color 等結構，var_to_str 會印得比 str() 更漂亮
		output_segments.append(var_to_str(arg) if typeof(arg) > TYPE_STRING else str(arg))
	
	var final_string = " ❖ ".join(output_segments)
	
	# 使用富文本輸出：[DEBUG] 顯示為青色(cyan)，內容顯示為淡灰色方便閱讀
	print_rich("[color=cyan][DEBUG][/color] [color=light_gray]%s[/color]" % final_string)

func _ready() -> void:
	# 初始位置固定
	global_position = Vector2(4, -3)
	velocity = Vector2.ZERO # 初始速度歸零，等待開始
	current_state = State.READY
	current_room_index = 0
	
	# 💡 訂閱父節點的 game_started 信號
	var parent = get_parent()
	if parent and parent.has_signal("game_started"):
		parent.game_started.connect(_on_game_started)
	
	print("遊戲等待中，請按下任意鍵開始...")

# 3. 接收到信號後觸發的邏輯
func _on_game_started() -> void:
	if current_state == State.READY:
		print("received sinal: game start")
		current_state = State.WALK

func _process(delta: float) -> void:
	#debug([State.keys()[current_state], current_room_index, is_on_floor(),sprite.global_position])
	
	var target_room_index = floor((global_position.x + 80 ) / ROOM_WIDTH)
	if target_room_index > 1:
		target_room_index = 0
	
	# 如果主角跨區了
	#if target_room_index != current_room_index and current_room_index - target_room_index == 2:
		#current_room_index = target_room_index
		#global_position.x = global_position.x - 320
	if global_position.x > 1.5 * ROOM_WIDTH:
		global_position.x = -0.5 * ROOM_WIDTH
	
	# 狀態 1：等待遊戲開始
	if current_state == State.READY:
		#if Input.is_action_just_pressed("jump"): 
		# 東西改成用信號的方式寫
		#if Input.is_anything_pressed():
			#print("Game start!")
			#current_state = State.WALK
		return # 尚未開始前，不執行後續輸入
		
	# 狀態 2：死亡狀態，不接收任何輸入
	if current_state == State.DIE:
		return


func _physics_process(delta: float) -> void:
	# 處理重力（死亡時仍有重力讓角色掉落，受傷也需要重力）
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# 處理跳躍（只有在 WALK 或 JUMP 狀態且在地面時可以跳）
	if Input.is_action_just_pressed("jump") and is_on_floor() and ( current_state == State.IDLE or current_state == State.WALK):
		velocity.y = JUMP_VELOCITY
		current_state = State.JUMP
	
	# 如果是遊戲開始前的 IDLE 或死亡狀態，停止物理移動邏輯（但保留 move_and_slide 讓重力生效）
	if current_state == State.IDLE || current_state == State.READY:
		velocity.x = 0
		move_and_slide()
		_update_animation()
		return
		
	if current_state == State.DIE:
		velocity.x = 0
		move_and_slide()
		return



	velocity.x = SPEED

	# 執行移動與碰撞
	move_and_slide()

	# 每幀檢查是否踩到有害方塊
	_check_special_tiles()
	
	# 處理動畫狀態機切換（移除了原本的 is_moving 傳參，改由內部速度判定）
	_update_animation()


## 偵測 TileMapLayer 上方塊的自訂屬性 (Custom Data)
func _check_special_tiles() -> void:
	if current_state == State.DAMAGED or current_state == State.DIE or current_state == State.READY:
		return
		
	# 遍歷這格幀所有發生的碰撞
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 確保碰撞到的是我們設定的 TileMapLayer
		if collider is TileMapLayer:
			var local_pos = collider.to_local(collision.get_position() - collision.get_normal() * 5)
			var tile_coord = collider.local_to_map(local_pos)
			var tile_data = collider.get_cell_tile_data(tile_coord)
			
			if tile_data:
				# 讀取你在 TileSet 裡面設定的 Custom Data Layer 名稱
				var is_harmful = tile_data.get_custom_data("is_harmful")
				if is_harmful == true:
					current_state = State.DAMAGED
					_take_damage()
				#var feature = tile_data.get_custom_data("feature")
				#debug([feature])
				#if feature:
					#_special_effect(feature);
	_check_trigger_tiles()
				

func _check_trigger_tiles() -> void:
	debug(["enter _check_trigger_tiles0"])
	if current_state == State.READY or current_state == State.DIE:
		return
	debug(["enter _check_trigger_tiles1"])
	if tilemap_layer:
		# 💡 方法：用角色「腳底」的全局坐標，去換算成 TileMap 的格子坐標
		# 如果你的角色錨點 (Position) 在中心，可以用 global_position + Vector2(0, 16) 往下探測
		var detect_position = global_position
		debug(["enter _check_trigger_tiles2"])

		# 轉化為 TileMapLayer 的本地與地圖網格坐標
		var local_pos = tilemap_layer.to_local(detect_position)
		var tile_coord = tilemap_layer.local_to_map(local_pos)
		debug([tile_coord])
		
		# 抓取該格子的資料
		var tile_data = tilemap_layer.get_cell_tile_data(tile_coord)
		
		if tile_data:
			var feature = tile_data.get_custom_data("feature")
			debug([feature])
			if feature and feature != "":
				_special_effect(feature)

func _special_effect(feature: String) -> void:
	match feature:
		"super_jump":
			velocity.y = -250

## 受傷與死亡邏輯
func _take_damage() -> void:
	velocity.x = -150 if sprite.flip_h else 150 # 稍微加大擊退力道
	velocity.y = -250
	#velocity.x = -velocity.x * 20
	#velocity.y = -velocity.y * 20
	
	sprite.play("main_char_dmged")
	
	# 監聽動畫結束事件
	if sprite.is_connected("animation_finished", Callable(self, "_on_damage_animation_finished")):
		sprite.disconnect("animation_finished", Callable(self, "_on_damage_animation_finished"))
	sprite.animation_finished.connect(Callable(self, "_on_damage_animation_finished"), CONNECT_ONE_SHOT)


func _on_damage_animation_finished() -> void:
	if current_state == State.DAMAGED:
		_die()


func _die() -> void:
	current_state = State.DIE
	velocity.x = 0 # 留給重力繼續掉落，但 X 軸歸零
	sprite.play("main_char_die")



## 動態更新 AnimationPlayer（移除外部傳參，改為自動判定）
func _update_animation() -> void:
	# 如果正在播受傷或死亡，交由對應邏輯處理，不打斷
	if current_state == State.DAMAGED or current_state == State.DIE:
		return
	
	if current_state == State.READY:
		sprite.play("main_char_idle")
		return

	if not is_on_floor():
		# Godot 坐標系中：Y > 0 是向下掉，Y < 0 是向上跳
		if velocity.y < 0:
			sprite.play("main_char_jump_up")
		else:
			sprite.play("main_char_jump_down")
	else:
		# 待在地面上時，根據 X 軸速度判定播走路還是靜止動畫
		if velocity.x != 0:
			current_state = State.WALK
			sprite.play("main_char_walk")
		else:
			current_state = State.IDLE
			sprite.play("main_char_idle")
