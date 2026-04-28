class_name EnemyData
extends Resource
## 敌人数据。定义敌人的属性，由 EnemySpawner 实例化为具体敌人节点。

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 20
@export var speed: float = 60.0
@export var damage: int = 5
@export var exp_reward: int = 2
@export var gold_reward: int = 1
@export var sprite: Texture2D

@export_group("生成")
@export var spawn_weight: float = 1.0
@export var min_spawn_time: float = 0.0
