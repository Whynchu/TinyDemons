extends RefCounted
class_name SoundClipCatalog

## Single source of truth for runtime and editor-preview audio paths.

const SOUNDS_PATH := "res://assets/sounds/"
const BATTLE_PATH := SOUNDS_PATH + "10_Free_RPG_Battle_SFX/"
const UI_PATH := SOUNDS_PATH + "10_ui_sfx_free_samples/"
const KH_UI_PATH := SOUNDS_PATH + "reconstructed_ui/"
const SELFMADE_PATH := SOUNDS_PATH + "Selfmade FX/"
const SELFMADE_REVERB_PATH := SELFMADE_PATH + "Reverb/"
const TITLE_MUSIC_PATH := SOUNDS_PATH + "Soundtrack/digital_forever.mp3"
const RUN_MUSIC_PATH := SOUNDS_PATH + "Soundtrack/Dungeon-Crawl.wav"

const CLIPS: Dictionary = {
	"slash": BATTLE_PATH + "22_Slash_04.wav",
	"miss": BATTLE_PATH + "35_Miss_Evade_02.wav",
	"flesh": BATTLE_PATH + "77_flesh_02.wav",
	"bite": BATTLE_PATH + "08_Bite_04.wav",
	"block": BATTLE_PATH + "39_Block_03.wav",
	"flee": BATTLE_PATH + "51_Flee_02.wav",
	"enemy_death": BATTLE_PATH + "69_Enemy_death_01.wav",
	"impact_flesh": BATTLE_PATH + "15_Impact_flesh_02.wav",
	"encounter": BATTLE_PATH + "55_Encounter_02.wav",
	"claw": BATTLE_PATH + "03_Claw_03.wav",
	"crit": SELFMADE_PATH + "Crit.wav",
	"imbue_impact": SELFMADE_PATH + "IMBUEimpact.wav",
	"magic_cast": BATTLE_PATH + "55_Encounter_02.wav",
	"magic_hit": BATTLE_PATH + "15_Impact_flesh_02.wav",
	"ui_hover": SELFMADE_REVERB_PATH + "CursorMove.wav",
	"ui_confirm": SELFMADE_REVERB_PATH + "Confirm.wav",
	"ui_decline": SELFMADE_REVERB_PATH + "BACK.wav",
	"ui_no_input": SELFMADE_PATH + "NOINPUT.wav",
	"ui_denied": UI_PATH + "033_Denied_03.wav",
	"ui_use_item": UI_PATH + "051_use_item_01.wav",
	"ui_equip": UI_PATH + "070_Equip_10.wav",
	"ui_unequip": UI_PATH + "071_Unequip_01.wav",
	"ui_buy_sell": UI_PATH + "079_Buy_sell_01.wav",
	"ui_pause": SELFMADE_REVERB_PATH + "Blip.wav",
	"charge_attack": SELFMADE_REVERB_PATH + "ChargedAttackwav.wav",
	"use_flame": SELFMADE_PATH + "UseFlame.wav",
	"ui_unpause": KH_UI_PATH + "sys-close.sms-real.wav",
	"enemy_alert": KH_UI_PATH + "sys-chagef1.sms-real.wav",
	"item_pickup": KH_UI_PATH + "sys-itemget.sms-real.wav",
	"chest_unlock": KH_UI_PATH + "sys-tresure.sms-real.wav",
	"chest_reward": KH_UI_PATH + "sys-money-get.sms-real.wav",
	"run_clear": KH_UI_PATH + "sys-money-get.sms-real.wav",
	"level_up": KH_UI_PATH + "ef-mon-up.sms-real.wav",
	"enemy_hit_1": KH_UI_PATH + "BTL-MON-HIT01.sms-real.wav",
	"enemy_hit_2": KH_UI_PATH + "BTL-MON-HIT02.sms-real.wav",
	"enemy_hit_3": KH_UI_PATH + "BTL-MON-HIT03.sms-real.wav",
	"enemy_hit_4": KH_UI_PATH + "BTL-MON-HIT04.sms-real.wav",
	"orb_hit": KH_UI_PATH + "BTL-MON-HIT04.sms-real.wav",
	"enemy_hit_5": KH_UI_PATH + "BTL-MON-HIT05.sms-real.wav",
	"enemy_hit_6": KH_UI_PATH + "BTL-MON-HIT06.sms-real.wav",
	"target_release": KH_UI_PATH + "sys-cansel.sms-real.wav",
	"foot_left": KH_UI_PATH + "sys-sr-footl.sms-real.wav",
	"foot_right": KH_UI_PATH + "sys-sr-footr.sms-real.wav",
	"slime_spawn": SELFMADE_PATH + "SlimeSpawn.wav",
	"slime_move": SELFMADE_PATH + "SlimeMove.wav",
}


static func path_for(sound_name: StringName) -> String:
	if sound_name == &"title_music":
		return TITLE_MUSIC_PATH
	if sound_name == &"run_music":
		return RUN_MUSIC_PATH
	return String(CLIPS.get(String(sound_name), ""))


static func preferred_audio_path(path: String) -> String:
	var ogg_path := path.get_basename() + ".ogg"
	return ogg_path if ResourceLoader.exists(ogg_path) else path
