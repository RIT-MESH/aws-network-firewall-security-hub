import json
s = json.load(open(r"_schema.json", encoding="utf-16"))
prov = list(s["provider_schemas"].values())[0]

def show(b, indent=0):
    pad = "  "*indent
    for name, attr in b.get("attributes", {}).items():
        req = " REQUIRED" if attr.get("required") else ""
        opt = " OPTIONAL" if attr.get("optional") else ""
        comp = " COMPUTED" if attr.get("computed") else ""
        print(f"{pad}attr {name}: {json.dumps(attr.get('type'))}{req}{opt}{comp}")
    bts = b.get("block_types", {})
    if isinstance(bts, list):
        items = [(bt.get("type_name"), bt) for bt in bts]
    else:
        items = list(bts.items())
    for tn, bt in items:
        if isinstance(bt, dict):
            card = bt.get("cardinality") or bt.get("min_items")
            print(f"{pad}block {tn} ({card})")
            show(bt.get("block", {}), indent+1)

for rn in ["aws_networkfirewall_firewall","aws_networkfirewall_firewall_policy","aws_networkfirewall_rule_group","aws_networkfirewall_logging_configuration"]:
    print("====", rn, "====")
    show(prov["resource_schemas"][rn]["block"])