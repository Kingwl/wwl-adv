class_name EnemyData
extends Resource
## 敌人数据。定义敌人的属性，由 EnemySpawner 实例化为具体敌人节点。

const BEHAVIOR_CHASE := &"chase"
const BEHAVIOR_FAST_CHASE := &"fast_chase"
const BEHAVIOR_BRUTE_CHASE := &"brute_chase"
const BEHAVIOR_DASH := &"dash"
const BEHAVIOR_RANGED := &"ranged"

@export var id: StringName
@export var display_name: String
@export var max_hp: int = 20
@export var speed: float = 60.0
@export var damage: int = 5
@export var exp_reward: int = 2
@export var gold_reward: int = 1
@export var sprite: Texture2D
@export var animation_sheet: Texture2D
@export var animation_frame_size: Vector2i = Vector2i(64, 64)
@export var animation_columns: int = 6
@export var contact_damage_cooldown: float = 1.0
@export var collision_radius: float = 14.0
@export var visual_scale: float = 1.0
@export var visual_modulate: Color = Color.WHITE
@export var tags: Array[StringName] = []

@export_group("行为")
@export var behavior_id: StringName = BEHAVIOR_CHASE
@export var dash_speed_multiplier: float = 2.6
@export var dash_windup: float = 0.22
@export var dash_duration: float = 0.32
@export var dash_recover_duration: float = 0.42
@export var dash_cooldown: float = 2.4
@export var preferred_range: float = 260.0
@export var retreat_range: float = 150.0
@export var attack_range: float = 360.0
@export var attack_cooldown: float = 2.0
@export var projectile_damage: int = 0
@export var projectile_speed: float = 280.0
@export var projectile_range: float = 420.0
@export var projectile_radius: float = 5.0
@export var projectile_modulate: Color = Color.WHITE

@export_group("生成")
@export var spawn_weight: float = 1.0
@export var min_spawn_time: float = 0.0
@export var max_spawn_time: float = -1.0
@export var pack_size: int = 1
