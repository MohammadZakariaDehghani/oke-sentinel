# oke-sentinel

An OCI landing zone that provisions a managed Kubernetes cluster (OKE) and runs
a self-hosted Elastic Stack on it as the platform's logging, metrics and
security-monitoring backend.

This is a portfolio project, not a production system. Nothing here has been
applied to a live tenancy.

**This README is a placeholder** — the full one, with the architecture diagram,
data flow, cost notes and prerequisites, is still to be written.

In the meantime:

- **[docs/running-and-testing.md](docs/running-and-testing.md)** — how to run
  and test all of this, including a local kind cluster that exercises the whole
  log pipeline with no OCI account
- **[docs/detections.md](docs/detections.md)** — the six detection rules, what
  each catches and why, mapped to MITRE ATT&CK
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — development setup and ground rules

```bash
make tools-check   # what is installed
make lint          # every static check
make test          # unit tests, including the detection rules
make kind-up && make local-stack && make local-verify   # the real demo
```

## Licence

MIT. See [LICENSE](LICENSE).
