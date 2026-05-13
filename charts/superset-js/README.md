# superset-js

Production Helm chart for [superset-js](https://github.com/gildedpleb/superset-js) — the Bun/TypeScript concurrent pipeline that continuously mines real-world linter configurations.

This chart deploys:

- The main application as a single replica
- A **Litestream sidecar** that continuously replicates the SQLite WAL to your MinIO instance
- Granular feature flags so you can roll out normalization pathways incrementally

## Prerequisites

- Kubernetes cluster with Longhorn (or any `ReadWriteOnce` storage)
- MinIO running in-cluster (`minio` Service in the `minio` namespace on port 9000)
- `helm` and `kubectl` configured

## Installation

### 1. Create the namespace

```bash
kubectl create namespace superset-js
```

### 2. Create the Secret (do this once)

```bash
kubectl create secret generic superset-js-secrets \
  --namespace superset-js \
  --from-literal=GITHUB_TOKEN=ghp_your_classic_pat \
  --from-literal=MINIO_ACCESS_KEY=your_minio_key \
  --from-literal=MINIO_SECRET_KEY=your_minio_secret
```

### 3. Install the chart

```bash
helm install superset-js gildedpleb/superset-js \
  --namespace superset-js
```

## Upgrading

```bash
# Enable a specific pathway
helm upgrade superset-js gildedpleb/superset-js \
  --namespace superset-js \
  --set env.ENABLE_NORMALIZATION_OXLINT_RAW=true
```

### Enabling Normalization Pathways (Granular Rollout)

This is the key feature of the chart + application combo.

```bash
# Enable only the first pathway you're working on
helm upgrade superset-js gildedpleb/superset-js \
  --namespace superset-js \
  --set enable.normalization.oxlintRaw=true

# Later, when the next pathway is ready
helm upgrade superset-js gildedpleb/superset-js \
  --namespace superset-js \
  --set enable.normalization.oxlintJsDeps=true
```

You can also edit `values.yaml` and re-apply.

## Uninstalling

```bash
helm uninstall superset-js --namespace superset-js
```

**Note**: The PVC and Secret are **not** deleted automatically (this is intentional and safe).

To fully clean up:

```bash
kubectl delete pvc superset-js -n superset-js
kubectl delete secret superset-js-secrets -n superset-js
kubectl delete namespace superset-js
```

## Data Migration (One-time)

After the first install you will want to bring your existing ~1.5 GB database into the cluster.

**Recommended safe approaches**:

- Use a temporary debug pod that mounts the PVC + `sqlite3 .backup`
- Or use Litestream tooling to seed the initial snapshot

Never copy a live WAL-mode database with plain `cp`.

## Configuration

### Key Values

| Key                  | Description                               | Default               |
| -------------------- | ----------------------------------------- | --------------------- |
| `persistence.size`   | Size of the database PVC                  | `5Gi`                 |
| `litestream.enabled` | Enable continuous backup sidecar          | `true`                |
| `secretName`         | Name of the Secret containing credentials | `superset-js-secrets` |

## Environment Variables (Fully Extensible)

This chart uses a flat `env:` map so you can add or change any environment variable without modifying the chart.

### Example

```yaml
env:
  ENABLE_INGESTION: "true"
  ENABLE_NORMALIZATION_OXLINT_RAW: "false"
  ENABLE_NORMALIZATION_OXLINT_JS_DEPS: "false"

  # Add new pathways here as you develop them
  # ENABLE_NORMALIZATION_ESLINT: "false"
  # ENABLE_NORMALIZATION_BIOME: "false"
```

## Troubleshooting

- **Pod won't start** — Check logs: `kubectl logs -l app.kubernetes.io/name=superset-js -n superset-js`
- **Litestream failing** — Verify the Secret has `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY`, and that the bucket exists in MinIO.
- **Feature flags not applying** — Confirm the env vars are present in the pod spec and restart if needed.
- Local development port-forward: `kubectl port-forward -n minio svc/minio 9000:9000`

## How to Add a New Normalization Pathway

1. Add the new flag under `enable.normalization` in `values.yaml`.
2. Update `templates/deployment.yaml` to inject the new `ENABLE_NORMALIZATION_XXX` environment variable.
3. Update the application code in `superset-js` (`src/main.ts`) to read and respect the flag.
4. Update this README and the docs in the main repo.
5. Only enable the flag in production after the pathway is complete and tested locally via `dev-normalization.sh`.

## Architecture Notes

- Single pod design (main app + Litestream sidecar) to keep all stages running "in unison" on the same PVC.
- Direct SQLite access everywhere (no HTTP abstraction).
- Local development uses `scripts/dev-normalization.sh` + Litestream restore from MinIO for fresh snapshots without burning GitHub quota.
