import json
p = r"C:\Users\rites\AppData\Local\Temp\aws_schema.json"
with open(p, encoding="utf-8") as f:
    s = json.load(f)
prov = list(s["provider_schemas"].values())[0]
for rname in ("aws_networkfirewall_firewall_policy","aws_networkfirewall_rule_group","aws_networkfirewall_logging_configuration"):
    print("====", rname, "====")
    rs = prov["resource_schemas"][rname]["block"]
    def show(b, indent=0):
        pad = "  " * indent
        for name, attr in b.get("attributes", {}).items():
            print(f"{pad}attr {name}: {json.dumps(attr.get('type'))}")
        for bt in b.get("block_types", []):
            print(f"{pad}block {bt['type_name']} ({bt.get('cardinality')})")
            show(bt["block"], indent + 1)
    show(rs)