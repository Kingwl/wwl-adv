class_name PlayerData
extends Resource
## 玩家角色基础数据。

@export var id: StringName
@export var display_name: String
@export var move_speed: float = 150.0
@export var max_hp: int = 100
@export var pickup_radius: float = 40.0
@export var sprite: Texture2D

@export_group("初始装备")
@export var starting_weapon_id: StringName
