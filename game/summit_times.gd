extends RefCounted

var summit: int
var best: Dictionary = {}
var arrivals: Dictionary = {}
var best_clock := ""
var best_summary := ""
var finish_summary := ""
var split_line := ""
var split_stop := -1

func _init(summit_id: int) -> void:
	summit=summit_id

static func clock(centiseconds: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d.%02d" % [centiseconds/6000,centiseconds/100%60,centiseconds%100]

func use_best(record: Dictionary) -> void:
	best=record
	best_clock=clock(record.splits[summit])
	best_summary="最快登頂 %s · %d 次起跳 · %d 次跌落" % [best_clock,record.jumps,record.falls]

func load_best(value: Variant) -> void:
	if not value is Dictionary: return
	var splits: Variant=value.get("splits")
	if not splits is Dictionary or not splits.get(summit) is int or splits[summit]<=0: return
	for key: String in ["jumps","falls"]:
		if not value.get(key) is int or value[key]<0: return
	for id: Variant in splits:
		if not id is int or id<=0 or not splits[id] is int or splits[id]<=0 or splits[id]>splits[summit]: return
	use_best(value)

func start_run() -> void:
	arrivals={}
	finish_summary=""
	split_line=""
	split_stop=-1

func land(id: int, elapsed: float, jumps: int, falls: int) -> void:
	split_line=""
	if id<=0 or arrivals.has(id): return
	var time:=roundi(elapsed*100)
	arrivals[id]=time
	split_stop=id
	var reference: Dictionary=best.get("splits",{})
	var delta: int=time-reference.get(id,time)
	var difference:="%.2f 秒" % (absi(delta)/100.0)
	if id!=summit:
		if reference.has(id):
			split_line="同紀錄持平" if delta==0 else ("比紀錄快 " if delta<0 else "比紀錄慢 ")+difference
		return
	if best.is_empty():
		finish_summary="首次登頂 · "+clock(time)
	elif delta<0:
		finish_summary="新紀錄 %s · 快咗 %s" % [clock(time),difference]
	elif delta==0:
		finish_summary="追平紀錄 · "+clock(time)
	else:
		finish_summary="今次 %s · 慢咗 %s\n%s" % [clock(time),difference,best_summary]
	if best.is_empty() or delta<0:
		use_best({"splits":arrivals.duplicate(),"jumps":jumps,"falls":falls})

func pace_at(id: int, elapsed: float) -> String:
	if id==split_stop and not split_line.is_empty() and elapsed<arrivals[id]/100.0+3.0:
		return split_line
	return ""
