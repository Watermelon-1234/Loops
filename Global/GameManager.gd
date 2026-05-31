extends Node

# 全域追蹤的數據
var death_count: int = 0

## 增加死亡次數並印出（未來可以在這裡觸發 UI 更新）
func add_death() -> void:
	death_count += 1

var respawn_position: Vector2 = Vector2.ZERO

func update_respawn_position(global_position: Vector2) -> void:
	respawn_position = global_position
