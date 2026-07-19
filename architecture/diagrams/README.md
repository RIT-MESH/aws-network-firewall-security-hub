# Diagrams

Architecture diagrams for the centralized inspection pattern.

## Architecture-as-code diagram (Mingrammer `diagrams`)

- `generate_architecture.py` - Python source that generates the architecture
  diagram using the [Mingrammer diagrams](https://diagrams.mingrammer.org/)
  package.
- `aws-network-firewall-architecture.svg` - generated SVG (displayed in the
  root README).
- `aws-network-firewall-architecture.png` - generated PNG.
- `requirements.txt` - Python dependency pin.

Regenerate after relevant architecture changes:

```bash
python -m pip install -r requirements.txt
python generate_architecture.py
```

Graphviz (`dot`) must be installed and available in `PATH`.

The GitHub Actions workflow `.github/workflows/architecture-diagram.yml` verifies
that committed artifacts are up to date on every pull request and push to
`main`.

## Mermaid diagram

- `architecture.mmd` - Mermaid source for the topology with Availability Zones,
  route tables, forward and return paths. Also embedded in the root README
  inside a collapsible `<details>` section.