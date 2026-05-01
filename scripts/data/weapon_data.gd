class_name WeaponData
extends Resource
## 武器数据。定义玩家可装备的自动攻击武器的属性。

enum WeaponType { MELEE, PROJECTILE, AREA }
enum Category { DAMAGE, DEFENSE, BUFF }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var weapon_type: WeaponType = WeaponType.MELEE
@export var category: Category = Category.DAMAGE
@export var icon: Texture2D

@export_group("攻击属性")
@export var damage: int = 10
@export var cooldown: float = 1.0
@export var range: float = 50.0
@export var projectile_speed: float = 300.0
@export var projectile_count: int = 1
@export var pierce: int = 0

@export_group("特殊属性")
@export var heal_amount: int = 0
@export var orbit_count: int = 0
@export var reflect_percent: float = 0.0
@export var field_radius: float = 0.0
@export var acquire_range: float = 0.0

## 构筑标签，用于构筑奖励、推荐和结算归类。
## 统一取值：近身 / 弹幕 / 场地 / 控制 / 爆发 / 生存。
@export var tags: Array[StringName] = []
## 机制标签，用于说明武器差异，不直接作为构筑奖励门槛。
@export var mechanism_tags: Array[StringName] = []

@export_group("升级")
@export var max_level: int = 8
@export var paths: Array[WeaponPath] = []
