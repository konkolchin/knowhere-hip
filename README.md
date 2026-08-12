# Knowhere (HIP) for Milvus on AMD GPUs

**Public branch `2.5`** of Knowhere with AMD HIP / GPU index support used by
[milvus-hip](https://github.com/konkolchin/milvus-hip) (`v2.5.4`).

| Piece | Public repo | Branch |
|-------|-------------|--------|
| Knowhere (this repo) | https://github.com/konkolchin/knowhere-hip | `2.5` |
| Milvus HIP | https://github.com/konkolchin/milvus-hip | `v2.5.4` |
| Harness | https://github.com/konkolchin/ann-harness-amd | `master` |

```bash
git clone -b 2.5 https://github.com/konkolchin/knowhere-hip.git
```

Build Milvus against this tree (local source dir or Git pin
`https://github.com/konkolchin/knowhere-hip.git` @ `2.5`) plus a hipVS /
hipRAFT install prefix. See the Milvus repo README and the harness
`scripts/build_milvus_layer3.sh`.

This is a tech-preview companion to the Milvus HIP port — not upstream
Knowhere `main`.

## Built with AI agents

Developed with **[Cursor](https://cursor.com)** and other AI coding agents
used across the team (e.g. Claude). Engineers own the port decisions and
validation; agents accelerate implementation and iteration.
