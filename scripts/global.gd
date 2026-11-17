extends Node


var save_icons: Array[Image]
var save_path: String
signal settings_changed(value)
var settings := {
	"fullscreen": false,
	"quality": Preset.MEDIUM,
}:
	set(value):
		settings = value
		settings_changed.emit()
enum Preset { LOW, MEDIUM, HIGH }
func save_capture() -> void:
	for i in save_icons:
		i.save_png("user://save_icon.png")

const HELMET_SLOT_HINT = preload("uid://boytvciuq1c8g")
const HELMET_HOVER_HINT = preload("uid://jc8ylrfom8mn")
const CHESTPLATE_SLOT_HINT = preload("uid://c6wv1gb2gsvra")
const CHESTPLATE_HOVER_HINT = preload("uid://bpb25e81u1ud6")
const LEGGINGS_SLOT_HINT = preload("uid://6un28ehnxl1f")
const LEGGINGS_HOVER_HINT = preload("uid://c4xehnjsyf7wq")
const BOOTS_SLOT_HINT = preload("uid://le7sxt7k6owg")
const BOOTS_HOVER_HINT = preload("uid://cdyle6uqtpdey")

const SLOT_NORMAL := preload("uid://j01ee113mi0m")
const SLOT_HOVER := preload("uid://ddsjvo8b3cuwi")
const ICON_SIZE := Vector2(56, 56)

const FULL_HEART = preload("uid://djyw2tavut04a")
const HALF_HEART = preload("uid://7l7eaqncaxjt")
const EMPTY_HEART = preload("uid://b5cis83cjqupe")

const FULL_SHANK = preload("uid://cq2wuxythsc3")
const HALF_SHANK = preload("uid://b0x815uer06mj")
const EMPTY_SHANK = preload("uid://b7t3cmr3ptk7o")


const RECIPES := [
	{"result": &"oak_planks", "count": 4, "ingredients": {&"oak_log": 1}},
	{"result": &"birch_planks", "count": 4, "ingredients": {&"birch_log": 1}},
	{"result": &"spruce_planks", "count": 4, "ingredients": {&"spruce_log": 1}},
	{"result": &"acacia_planks", "count": 4, "ingredients": {&"acacia_log": 1}},
	{"result": &"jungle_planks", "count": 4, "ingredients": {&"jungle_log": 1}},
	{"result": &"dark_oak_planks", "count": 4, "ingredients": {&"dark_oak_log": 1}},
	{"result": &"mangrove_planks", "count": 4, "ingredients": {&"mangrove_log": 1}},
	{"result": &"cherry_planks", "count": 4, "ingredients": {&"cherry_log": 1}},
	{"result": &"pale_oak_planks", "count": 4, "ingredients": {&"pale_oak_log": 1}},
	{"result": &"poplar_planks", "count": 4, "ingredients": {&"poplar_log": 1}},
	{"result": &"bamboo_planks", "count": 4, "ingredients": {&"bamboo_block": 1}},
	{"result": &"crimson_planks", "count": 4, "ingredients": {&"crimson_stem": 1}},
	{"result": &"warped_planks", "count": 4, "ingredients": {&"warped_stem": 1}},
	{"result": &"oak_planks", "count": 4, "ingredients": {&"stripped_oak_log": 1}},
	{"result": &"birch_planks", "count": 4, "ingredients": {&"stripped_birch_log": 1}},
	{"result": &"spruce_planks", "count": 4, "ingredients": {&"stripped_spruce_log": 1}},
	{"result": &"acacia_planks", "count": 4, "ingredients": {&"stripped_acacia_log": 1}},
	{"result": &"jungle_planks", "count": 4, "ingredients": {&"stripped_jungle_log": 1}},
	{"result": &"dark_oak_planks", "count": 4, "ingredients": {&"stripped_dark_oak_log": 1}},
	{"result": &"mangrove_planks", "count": 4, "ingredients": {&"stripped_mangrove_log": 1}},
	{"result": &"cherry_planks", "count": 4, "ingredients": {&"stripped_cherry_log": 1}},
	{"result": &"pale_oak_planks", "count": 4, "ingredients": {&"stripped_pale_oak_log": 1}},
	{"result": &"poplar_planks", "count": 4, "ingredients": {&"stripped_poplar_log": 1}},
	{"result": &"bamboo_planks", "count": 4, "ingredients": {&"stripped_bamboo_block": 1}},
	{"result": &"crimson_planks", "count": 4, "ingredients": {&"stripped_crimson_stem": 1}},
	{"result": &"warped_planks", "count": 4, "ingredients": {&"stripped_warped_stem": 1}},
	{"result": &"oak_planks", "count": 4, "ingredients": {&"stripped_oak_wood": 1}},
	{"result": &"birch_planks", "count": 4, "ingredients": {&"stripped_birch_wood": 1}},
	{"result": &"spruce_planks", "count": 4, "ingredients": {&"stripped_spruce_wood": 1}},
	{"result": &"acacia_planks", "count": 4, "ingredients": {&"stripped_acacia_wood": 1}},
	{"result": &"jungle_planks", "count": 4, "ingredients": {&"stripped_jungle_wood": 1}},
	{"result": &"dark_oak_planks", "count": 4, "ingredients": {&"stripped_dark_oak_wood": 1}},
	{"result": &"mangrove_planks", "count": 4, "ingredients": {&"stripped_mangrove_wood": 1}},
	{"result": &"cherry_planks", "count": 4, "ingredients": {&"stripped_cherry_wood": 1}},
	{"result": &"pale_oak_planks", "count": 4, "ingredients": {&"stripped_pale_oak_wood": 1}},
	{"result": &"poplar_planks", "count": 4, "ingredients": {&"stripped_poplar_wood": 1}},
	{"result": &"crimson_planks", "count": 4, "ingredients": {&"stripped_crimson_hyphae": 1}},
	{"result": &"warped_planks", "count": 4, "ingredients": {&"stripped_warped_hyphae": 1}},
	{"result": &"oak_planks", "count": 4, "ingredients": {&"oak_wood": 1}},
	{"result": &"birch_planks", "count": 4, "ingredients": {&"birch_wood": 1}},
	{"result": &"spruce_planks", "count": 4, "ingredients": {&"spruce_wood": 1}},
	{"result": &"acacia_planks", "count": 4, "ingredients": {&"acacia_wood": 1}},
	{"result": &"jungle_planks", "count": 4, "ingredients": {&"jungle_wood": 1}},
	{"result": &"dark_oak_planks", "count": 4, "ingredients": {&"dark_oak_wood": 1}},
	{"result": &"mangrove_planks", "count": 4, "ingredients": {&"mangrove_wood": 1}},
	{"result": &"cherry_planks", "count": 4, "ingredients": {&"cherry_wood": 1}},
	{"result": &"pale_oak_planks", "count": 4, "ingredients": {&"pale_oak_wood": 1}},
	{"result": &"poplar_planks", "count": 4, "ingredients": {&"poplar_wood": 1}},
	{"result": &"crimson_planks", "count": 4, "ingredients": {&"crimson_hyphae": 1}},
	{"result": &"warped_planks", "count": 4, "ingredients": {&"warped_hyphae": 1}},
	{"result": &"red_wool", "count": 1, "ingredients": {&"white_wool": 1, &"red_dye": 1}},
	{"result": &"green_wool", "count": 1, "ingredients": {&"white_wool": 1, &"green_dye": 1}},
	{"result": &"blue_wool", "count": 1, "ingredients": {&"white_wool": 1, &"blue_dye": 1}},
	{"result": &"cyan_wool", "count": 1, "ingredients": {&"white_wool": 1, &"cyan_dye": 1}},
	{"result": &"magenta_wool", "count": 1, "ingredients": {&"white_wool": 1, &"magenta_dye": 1}},
	{"result": &"yellow_wool", "count": 1, "ingredients": {&"white_wool": 1, &"yellow_dye": 1}},
	{"result": &"black_wool", "count": 1, "ingredients": {&"white_wool": 1, &"black_dye": 1}},
	{"result": &"gray_wool", "count": 1, "ingredients": {&"white_wool": 1, &"gray_dye": 1}},
	{"result": &"light_gray_wool", "count": 1, "ingredients": {&"white_wool": 1, &"light_gray_dye": 1}},
	{"result": &"white_wool", "count": 1, "ingredients": {&"string": 4}},
	{"result": &"orange_wool", "count": 1, "ingredients": {&"white_wool": 1, &"orange_dye": 1}},
	{"result": &"pink_wool", "count": 1, "ingredients": {&"white_wool": 1, &"pink_dye": 1}},
	{"result": &"light_blue_wool", "count": 1, "ingredients": {&"white_wool": 1, &"light_blue_dye": 1}},
	{"result": &"brown_wool", "count": 1, "ingredients": {&"white_wool": 1, &"brown_dye": 1}},
	{"result": &"pink_dye", "count": 2, "ingredients": {&"red_dye": 1, &"white_dye": 1}},
	{"result": &"orange_dye", "count": 2, "ingredients": {&"red_dye": 1, &"yellow_dye": 1}},
	{"result": &"light_blue_dye", "count": 2, "ingredients": {&"blue_dye": 1, &"white_dye": 1}},
	{"result": &"light_gray_dye", "count": 2, "ingredients": {&"gray_dye": 1, &"white_dye": 1}},
	{"result": &"gray_dye", "count": 2, "ingredients": {&"black_dye": 1, &"white_dye": 1}},
	{"result": &"lime_dye", "count": 2, "ingredients": {&"green_dye": 1, &"white_dye": 1}},
	{"result": &"light_blue_dye", "count": 2, "ingredients": {&"blue_dye": 1, &"white_dye": 1}},
	{"result": &"cyan_dye", "count": 2, "ingredients": {&"blue_dye": 1, &"green_dye": 1}},
	{"result": &"magenta_dye", "count": 2, "ingredients": {&"pink_dye": 1, &"purple_dye": 1}},
	{"result": &"stick", "count": 4, "ingredients": {&"plank": 2}},
	{"result": &"torch", "count": 4, "ingredients": {&"coal": 1, &"stick": 1}},
	{"result": &"snow_block", "count": 1, "ingredients": {&"snowball": 4}},
	{"result": &"crafting_table", "count": 1, "ingredients": {&"plank": 4}},
	{"result": &"wooden_pickaxe", "count": 1, "ingredients": [{&"plank": 1}, {&"plank": 1}, {&"plank": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wooden_axe", "count": 1, "ingredients": [{&"plank": 1}, {&"plank": 1}, null, {&"plank": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wooden_shovel", "count": 1, "ingredients": [null, {&"plank": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wooden_sword", "count": 1, "ingredients": [null, {&"plank": 1}, null, null, {&"plank": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wood_block", "count": 3, "ingredients": {&"log": 4}},
	{"result": &"wooden_hoe", "count": 1, "ingredients": [null, {&"plank": 1}, {&"plank": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"redstone_torch", "count": 1, "ingredients": {&"redstone_dust": 1, &"stick": 1}},
	{"result": &"furnace", "count": 1, "ingredients": [{&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}, null, {&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}]},
	{"result": &"hay_bale", "count": 1, "ingredients": [{&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}]},
	{"result": &"redstone_block", "count": 1, "ingredients": [{&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}]},
	{"result": &"white_bed", "count": 1, "ingredients": [{&"white_wool": 1}, {&"white_wool": 1}, {&"white_wool": 1}, {&"plank": 1}, {&"plank": 1}, {&"plank": 1}]},
	{"result": &"bread", "count": 1, "ingredients": [{&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}]},
	{"result": &"diamond_block", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}]},
	{"result": &"coal_block", "count": 1, "ingredients": [{&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}]},
	{"result": &"fence", "count": 3, "ingredients": [{&"plank": 1}, {&"stick": 1}, {&"plank": 1}, {&"plank": 1}, {&"stick": 1}, {&"plank": 1}]},
	{"result": &"lever", "count": 1, "ingredients": {&"stick": 1, &"cobblestone": 1}},
	{"result": &"stone_pickaxe", "count": 1, "ingredients": [{&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_shovel", "count": 1, "ingredients": [null, {&"cobblestone": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_sword", "count": 1, "ingredients": [null, {&"cobblestone": 1}, null, null, {&"cobblestone": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_axe", "count": 1, "ingredients": [{&"cobblestone": 1}, {&"cobblestone": 1}, null, {&"cobblestone": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_hoe", "count": 1, "ingredients": [null, {&"cobblestone": 1}, {&"cobblestone": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_pickaxe", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_shovel", "count": 1, "ingredients": [null, {&"iron_ingot": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_sword", "count": 1, "ingredients": [null, {&"iron_ingot": 1}, null, null, {&"iron_ingot": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_axe", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_hoe", "count": 1, "ingredients": [null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_pickaxe", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_shovel", "count": 1, "ingredients": [null, {&"gold_ingot": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_sword", "count": 1, "ingredients": [null, {&"gold_ingot": 1}, null, null, {&"gold_ingot": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_axe", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_hoe", "count": 1, "ingredients": [null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_pickaxe", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_shovel", "count": 1, "ingredients": [null, {&"diamond": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_sword", "count": 1, "ingredients": [null, {&"diamond": 1}, null, null, {&"diamond": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_axe", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_hoe", "count": 1, "ingredients": [null, {&"diamond": 1}, {&"diamond": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"fishing_rod", "count": 1, "ingredients": [{&"stick": 1}, null, null, {&"string": 1}, {&"stick": 1}, null, {&"string": 1}, null, {&"stick": 1}]},
	{"result": &"flint_and_steel", "count": 1, "ingredients": {&"flint": 1, &"iron_ingot": 1}},
	{"result": &"leather_cap", "count": 1, "ingredients": [{&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}]},
	{"result": &"leather_tunic", "count": 1, "ingredients": [{&"leather": 1}, null, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}]},
	{"result": &"leather_pants", "count": 1, "ingredients": [{&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}]},
	{"result": &"leather_boots", "count": 1, "ingredients": [{&"leather": 1}, null, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}]},
	{"result": &"iron_helmet", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}]},
	{"result": &"iron_chestplate", "count": 1, "ingredients": [{&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}]},
	{"result": &"iron_leggings", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}]},
	{"result": &"iron_boots", "count": 1, "ingredients": [{&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}]},
	{"result": &"golden_helmet", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}]},
	{"result": &"golden_chestplate", "count": 1, "ingredients": [{&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}]},
	{"result": &"golden_leggings", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}]},
	{"result": &"golden_boots", "count": 1, "ingredients": [{&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}]},
	{"result": &"diamond_helmet", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}]},
	{"result": &"diamond_chestplate", "count": 1, "ingredients": [{&"diamond": 1}, null, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}]},
	{"result": &"diamond_leggings", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}]},
	{"result": &"diamond_boots", "count": 1, "ingredients": [{&"diamond": 1}, null, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}]},
	{"result": &"golden_apple", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"apple": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}]},
	{"result": &"redstone_dust", "count": 9, "ingredients": {&"redstone_block": 1}},
	{"result": &"diamond", "count": 9, "ingredients": {&"diamond_block": 1}},
	{"result": &"gold_ingot", "count": 9, "ingredients": {&"gold_block": 1}},
	{"result": &"iron_ingot", "count": 9, "ingredients": {&"iron_block": 1}},
	{"result": &"gold_block", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}]},
	{"result": &"iron_block", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}]},
	#{"result": &"tnt", "count": 1, "ingredients": [{&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}]},
	#{"result": &"slime_block", "count": 1, "ingredients": [{&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}]},
	{"result": &"melon", "count": 1, "ingredients": [{&"melon_slice": 1}, {&"melon_slice": 1}, {&"melon_slice": 1}, {&"melon_slice": 1}, {&"melon_slice": 1}, {&"melon_slice": 1}, {&"melon_slice": 1}, {&"melon_slice": 1}, {&"melon_slice": 1}]},
	{"result": &"melon_seeds", "count": 1, "ingredients": {&"melon_slice": 1}},
	{"result": &"pumpkin_seeds", "count": 1, "ingredients": {&"pumpkin": 1}},
	{"result": &"red_dye", "count": 1, "ingredients": {&"beetroot": 1}},
	{"result": &"red_dye", "count": 1, "ingredients": {&"poppy": 1}},
	{"result": &"red_dye", "count": 1, "ingredients": {&"red_tulip": 1}},
	{"result": &"red_dye", "count": 2, "ingredients": {&"rose_bush": 1}},
	{"result": &"blue_dye", "count": 1, "ingredients": {&"cornflower": 1}},
	{"result": &"blue_dye", "count": 1, "ingredients": {&"lapis_lazuli": 1}},
	{"result": &"purple_dye", "count": 1, "ingredients": {&"red_dye": 1, &"blue_dye": 1}},
	{"result": &"packed_ice", "count": 1, "ingredients": [{&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}]},
	{"result": &"blue_ice", "count": 1, "ingredients": [{&"packed_ice": 1}, {&"packed_ice": 1}, {&"packed_ice": 1}, {&"packed_ice": 1}, {&"packed_ice": 1}, {&"packed_ice": 1}, {&"packed_ice": 1}, {&"packed_ice": 1}, {&"packed_ice": 1}]},
	{"result": &"gold_nugget", "count": 9, "ingredients": {&"gold_ingot": 1}},
	{"result": &"gold_ingot", "count": 1, "ingredients": [{&"gold_nugget": 1}, {&"gold_nugget": 1}, {&"gold_nugget": 1}, {&"gold_nugget": 1}, {&"gold_nugget": 1}, {&"gold_nugget": 1}, {&"gold_nugget": 1}, {&"gold_nugget": 1}, {&"gold_nugget": 1}]},
	{"result": &"iron_nugget", "count": 9, "ingredients": {&"iron_ingot": 1}},
	{"result": &"iron_ingot", "count": 1, "ingredients": [{&"iron_nugget": 1}, {&"iron_nugget": 1}, {&"iron_nugget": 1}, {&"iron_nugget": 1}, {&"iron_nugget": 1}, {&"iron_nugget": 1}, {&"iron_nugget": 1}, {&"iron_nugget": 1}, {&"iron_nugget": 1}]},
	{"result": &"emerald_block", "count": 1, "ingredients": [{&"emerald": 1}, {&"emerald": 1}, {&"emerald": 1}, {&"emerald": 1}, {&"emerald": 1}, {&"emerald": 1}, {&"emerald": 1}, {&"emerald": 1}, {&"gold_ingot": 1}]},
	{"result": &"emerald", "count": 9, "ingredients": {&"emerald_block": 1}},
]
