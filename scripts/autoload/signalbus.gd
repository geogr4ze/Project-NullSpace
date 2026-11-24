extends Node

#player signals
@warning_ignore("unused_signal")
signal shot
@warning_ignore("unused_signal")
signal hit
@warning_ignore("unused_signal")
signal energy
@warning_ignore("unused_signal")
signal enemy_bullet_hit
@warning_ignore("unused_signal")
signal player_shield
@warning_ignore("unused_signal")
signal dash

#UI signals
@warning_ignore("unused_signal")
signal score(points: int)
@warning_ignore("unused_signal")
signal energy_low
@warning_ignore("unused_signal")
signal next_wave
@warning_ignore("unused_signal")
signal money(amount: int)
#enemy signals
@warning_ignore("unused_signal")
signal enemy_hit(body_hit: Node2D)
@warning_ignore("unused_signal")
signal kc_point
@warning_ignore("unused_signal")
signal new_enemy(enemy_type: int)
@warning_ignore("unused_signal")
signal shot_RG(bullet: RigidBody2D)
@warning_ignore("unused_signal")
signal shield(body_hit: Node2D)
@warning_ignore("unused_signal")
signal mine_dispense(mine: RigidBody2D)
@warning_ignore("unused_signal")
signal mine_hit

#game signals
@warning_ignore("unused_signal")
signal spawn_energy(energy: RigidBody2D)
@warning_ignore("unused_signal")
signal player_death
@warning_ignore("unused_signal")
signal wave_complete(completed_wave: int)
@warning_ignore("unused_signal")
signal test_mode
