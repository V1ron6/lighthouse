extends Node
## Global signal hub (autoload: EventBus).
## Scenes emit and listen here so they never depend on each other directly.

# --- Economy ---
signal qubits_changed(new_amount: int)
signal item_purchased(item_id: String, price: int)
signal item_sold(item_id: String, price: int)

# --- Rank ---
signal points_changed(new_points: int)
signal rank_changed(new_index: int, old_index: int)

# --- Base ---
signal base_health_changed(current: int, maximum: int)
signal core_integrity_changed(current: int, maximum: int)
signal core_destroyed
signal base_attacked(strength: int)
## choice is "defend" or "continue"
signal base_attack_resolved(choice: String)

# --- Missions ---
signal mission_started(mission_id: String)
signal mission_completed(mission_id: String, success: bool)
signal mission_abandoned(mission_id: String)

# --- Colonies ---
signal colony_fell(colony_id: String)
signal colony_retaken(colony_id: String)

# --- Story ---
signal radio_message(message_id: String)
