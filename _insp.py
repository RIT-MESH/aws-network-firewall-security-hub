import json
for enc in ("utf-16", "utf-8-sig", "utf-8"):
    try:
        s = json.load(open(r"_schema.json", encoding=enc))
        print("parsed with", enc)
        break
    except Exception as e:
        print("fail", enc, e)
        s = None
prov = list(s["provider_schemas"].values())[0]
def show(b, indent=0):
    pad = "  "*indent
    for name, attr in b.get("attributes", {}).items():
        print(f"{pad}attr {name}: {json.dumps(attr.get('type'))}")
    for bt in b.get("block_types", []):
        print(f"{pad}block {bt['type_name']} ({bt.get('cardinality')})")
        show(bt["block"], indent+1)
for rn in ["aws_networkfirewall_firewall"]:
    print("====", rn, "====")
    show(prov["resource_schemas"][rn]["block"])