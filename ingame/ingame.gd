extends Node2D

signal game_started

const SRC_LINK = "https://github.com/Watermelon-1234/Loops"

@onready var player: CharacterBody2D = $MainCharacter
@onready var camera: Camera2D = $Camera2D

@onready var menu: Control = $CanvasLayer/Control
@onready var start_button: Button = $CanvasLayer/Control/ColorRect/MarginContainer/VBoxContainer/HBoxContainer/Start
@onready var src_button: Button = $CanvasLayer/Control/ColorRect/MarginContainer/VBoxContainer/HBoxContainer/Source
@onready var tutorial_button: Button = $CanvasLayer/Control/ColorRect/MarginContainer/VBoxContainer/HBoxContainer/Tutorial
@onready var option_button: Button = $CanvasLayer/Control/ColorRect/MarginContainer/VBoxContainer/Option

# 每一區（房間）的寬度：20 格 * 8 像素 = 160 像素
const ROOM_WIDTH = 192

# 追蹤當前主角在哪一區（0 代表 A 區，1 代表 B 區，以此類推）
var current_room_index: int = 0

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
	# 初始化相機位置在 (0, 0)
	camera.global_position = Vector2(0,0)
	current_room_index = 0
	
	# UIs
	menu.visible = true
	start_button.pressed.connect(_game_start)
	src_button.pressed.connect(_open_src)
	
func _game_start() -> void:
	# 隱藏menu
	menu.visible = false
	
	# 開始遊戲
	game_started.emit()

func _open_src() -> void:
	OS.shell_open(SRC_LINK)

func _process(_delta: float) -> void:
	#debug([current_room_index])
	# 透過無條件捨去（floor）動態計算主角目前落在哪個房間區間
	# 例如：X 座標 0~159 會得到 0 (A區)；160~319 會得到 1 (B區)
	var target_room_index = floor((player.global_position.x + (ROOM_WIDTH / 2 ) ) / ROOM_WIDTH)
	if target_room_index > 1:
		target_room_index = 0
	camera.global_position.y = player.global_position.y-30
	
	#if Input.is_anything_pressed():
		#print("pressed!")
		
	
	#print(camera.global_position)
	# 如果主角跨區了，就更新相機位置
	if target_room_index != current_room_index:
		current_room_index = target_room_index
		_switch_camera_room(current_room_index)

func _switch_camera_room(room_index: int) -> void:
	# 計算目標房間的相機新位置
	# 如果 Camera2D 的 Anchor Mode 是 Fixed Top Left，左上角就是 room_index * ROOM_WIDTH
	# 如果 Anchor Mode 是 Drag Center，則需要再加上半個畫面的偏移量
	var target_x = room_index * ROOM_WIDTH
	
	# 直接改變座標
	camera.global_position.x = target_x
	
	# 偵測用：方便你在輸出視窗確認切換邏輯是否正確
	print("相機切換至房間 ID: ", room_index, "，座標 X: ", target_x)
