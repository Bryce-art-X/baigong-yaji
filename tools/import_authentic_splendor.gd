extends SceneTree
## Imports exact 90 Splendor cards from D:/temp/refs/splendimax/Splendor Cards.csv
## and assigns coherent Chinese Craftsmanship worldbuilding names across Tier 1/2/3.

const COLOR_MAP := {
	"White": "jade",
	"Blue": "porcelain",
	"Green": "bamboo",
	"Red": "cinnabar",
	"Black": "ink",
}

const NAMES := {
	"1_jade": ["昆仑玉脉", "白水河玉滩", "玉龙喀什矿", "羊脂玉矿坑", "和田采玉坊", "墨玉河滩", "于阗古玉矿", "昆冈玉石窟"],
	"1_porcelain": ["高岭瓷土矿", "越窑青瓷口", "龙泉古窑口", "景德瓷泥滩", "曜变窑火坑", "磁州采泥坊", "汝州瓷石矿", "建窑柴火窑"],
	"1_bamboo": ["湘南翠竹林", "安吉毛竹山", "潇湘斑竹林", "宜兴紫竹坡", "蜀南竹海谷", "武夷翠竹溪", "莫干青竹坞", "天目竹材场"],
	"1_cinnabar": ["辰州朱砂矿", "万山丹砂窟", "贵州红砂井", "巴蜀漆树林", "湘西砂石坑", "丹崖赤矿脉", "滇南朱砂谷", "古法炼丹坊"],
	"1_ink": ["黄山松烟窑", "徽州古松林", "端溪采砚坑", "歙县龙尾坑", "祁门松烟坊", "易水松煤窑", "洮河采石滩", "澄泥淘沙池"],

	"2_jade": ["苏帮琢玉坊", "扬州玉雕行", "姑苏玉器局", "丝路玉商队", "天工琢玉阁", "玉雕世家坊"],
	"2_porcelain": ["景德镇官窑", "哥窑冰裂坊", "钧窑彩釉局", "海丝瓷船队", "官窑青花坊", "定窑白瓷行"],
	"2_bamboo": ["留青竹刻坊", "金陵竹雕局", "湘竹运河船", "嘉定竹人馆", "翠竹雅器号", "徽州竹编坊"],
	"2_cinnabar": ["果园厂漆坊", "剔红雕漆局", "闽南脱胎坊", "云锦朱丝号", "京城御漆行", "扬州螺钿坊"],
	"2_ink": ["胡开文墨庄", "端溪名砚坊", "徽墨京运船", "曹素功墨阁", "古琴斫琴坊", "宣纸老字号"],

	"3_jade": ["太和白玉殿", "和氏璧宝阁", "九龙玉玺殿", "乾坤玉山楼"],
	"3_porcelain": ["内府御窑阁", "瓷母万花殿", "秘色莲华宫", "元青花藏阁"],
	"3_bamboo": ["兰亭修竹阁", "竹林七贤殿", "千里江山斋", "潇湘翠微宫"],
	"3_cinnabar": ["赤金凤冠殿", "九龙剔红宫", "百鸟朝凤阁", "丹宸御宝殿"],
	"3_ink": ["天一藏书阁", "永乐大典殿", "曾侯乙礼殿", "文渊墨宝楼"],
}

func _init() -> void:
	var csv := FileAccess.open("D:/temp/refs/splendimax/Splendor Cards.csv", FileAccess.READ)
	if csv == null:
		printerr("Missing Splendor Cards.csv")
		quit(1)
		return

	var raw_old := RulesEngine.load_raw_data()
	var _hdr := csv.get_csv_line()
	var counters := {}
	var tier_idx := {1: 0, 2: 0, 3: 0}
	var cards: Array = []

	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 8 or row[0].strip_edges().is_empty():
			continue
		var tier := int(row[0])
		var bonus: String = COLOR_MAP[row[1].strip_edges()]
		var pv := int(row[2])
		var cost: Dictionary = {}
		var cols := ["ink", "porcelain", "bamboo", "cinnabar", "jade"] # Black, Blue, Green, Red, White
		for i in range(5):
			var v := int(row[3 + i])
			if v > 0:
				cost[cols[i]] = v
		var key := "%d_%s" % [tier, bonus]
		var idx := int(counters.get(key, 0))
		counters[key] = idx + 1
		tier_idx[tier] += 1
		var name_list: Array = NAMES[key]
		cards.append({
			"id": "t%d_%02d" % [tier, tier_idx[tier]],
			"tier": tier,
			"bonus": bonus,
			"prestige": pv,
			"name": str(name_list[idx]),
			"cost": cost,
		})

	var out := {"cards": cards, "masters": raw_old.get("masters", [])}
	var fw := FileAccess.open("res://data/craft_data.json", FileAccess.WRITE)
	fw.store_string(JSON.stringify(out, "  ") + "\n")
	print("Imported authentic Splendor 90 cards: %d cards, %d masters" % [cards.size(), out["masters"].size()])
	quit(0)
