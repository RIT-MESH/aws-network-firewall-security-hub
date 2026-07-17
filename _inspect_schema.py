import json
p = r"C:\Users\rites\AppData\Local\Temp\aws_schema.json"
with open(p, encoding="utf-8") as f:
    s = json.load(f)
prov = list(s["provider_schemas"].values())[0]
rs = prov["resource_schemas"]["aws_networkfirewall_firewall"]["block"]

def show(b, indent=0):
    pad = "  " * indent
    for name, attr in b.get("attributes", {}).items():
        print(f"{pad}attr {name}: {json.dumps(attr.get('type'))}")
    for bt in b.get("block_types", []):
        tn = bt["type_name"]
        ct = bt.get("cardinality")
        print(f"{pad}block {tn} ({ct})")
        show(bt["block"], indent + 1)

show(rs)