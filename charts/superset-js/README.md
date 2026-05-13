# superset-js Helm Chart

Production Helm chart for [superset-js](https://github.com/gildedpleb/superset-js) — the Bun/TypeScript concurrent pipeline that continuously mines real-world linter configurations from GitHub.

This chart deploys:

- The main application container
- A **Litestream sidecar** for continuous SQLite WAL replication to MinIO
- Full support for granular, extensible environment variable flags

## Prerequisites

- Kubernetes cluster with Longhorn (or compatible RWO storage)
- MinIO running in-cluster (`minio` Service in the `minio` namespace)
- `helm` and `kubectl` configured for your cluster

## Installation

### 1. Create the namespace

```bash
kubectl create namespace superset-js
```

### 2. Create the Secret (run once)

```bash
kubectl create secret generic superset-js-secrets \
  --namespace superset-js \
  --from-literal=GITHUB_TOKEN=ghp_your_classic_pat_here \
  --from-literal=MINIO_ACCESS_KEY=your_minio_access_key \
  --from-literal=MINIO_SECRET_KEY=your_minio_secret_key
```

### 3. Install the chart

```bash
helm install superset-js gildedpleb/superset-js --namespace superset-js
```

## Upgrading

```bash
helm upgrade superset-js gildedpleb/superset-js --namespace superset-js
```

### Enabling Normalization Pathways

Pathways are controlled via the flat `env:` map:

```bash
# Enable only the raw oxlint pathway
helm upgrade superset-js gildedpleb/superset-js \
  --namespace superset-js \
  --set env.ENABLE_NORMALIZATION_OXLINT_RAW=true
```

You can also edit `values.yaml` under the `env:` section and re-apply.

## Uninstalling

```bash
helm uninstall superset-js --namespace superset-js
```

**Note**: The PVC and Secret are preserved by default (intentional).

Full cleanup:

```bash
kubectl delete pvc superset-js -n superset-js
kubectl delete secret superset-js-secrets -n superset-js
kubectl delete namespace superset-js
```

## Data Migration (One-time)

After the first install, migrate your existing database safely into the cluster.

**Recommended methods**:

- Temporary debug pod + `sqlite3 .backup`
- Lit estream tooling for initial seed

Never use plain `cp` on a live WAL-mode database.

## Configuration

### Environment Variables (Fully Extensible)

This chart uses a simple `env:` map. Any variable you add here is automatically injected into the pod.

**Example in `values.yaml`**:

```yaml
env:
  ENABLE_INGESTION: "true"
  ENABLE_NORMALIZATION_OXLINT_RAW: "false"
  ENABLE_NORMALIZATION_OXLINT_JS_DEPS: "false"

  # Add new pathways as you develop them
  # ENABLE_NORMALIZATION_ESLINT: "false"
  # ENABLE_NORMALIZATION_BIOME: "false"
```

This design means you can add new normalization pathways without modifying the Helm chart.

### Key Values

| Key                  | Description                           | Default               |
| -------------------- | ------------------------------------- | --------------------- |
| `persistence.size`   | Size of the database PVC              | `5Gi`                 |
| `litestream.enabled` | Enable Litestream sidecar             | `true`                |
| `secretName`         | Name of the credentials Secret        | `superset-js-secrets` |
| `env.*`              | Any environment variable (extensible) | -                     |

## Troubleshooting

- **Pod not starting**: `kubectl logs -l app.kubernetes.io/name=superset-js -n superset-js --all-containers=true`
- **Litestream issues**: Check that the Secret contains `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY`, and that the bucket exists in MinIO.
- **Feature flags not applying**: Verify the env vars appear in the pod spec.
- Local dev port-forward: `kubectl port-forward -n minio svc/minio 9000:9000`

## How to Add a New Normalization Pathway

1. Add the new variable under `env:` in `values.yaml`.
2. Update the application code in `superset-js` (`src/main.ts`) to read and respect the flag.
3. Update this README if needed.
4. Only enable it in production after testing locally with `./scripts/dev-normalization.sh`.

## Architecture Notes

- Single-pod design (main app + Litestream sidecar) to keep all stages running together on the same PVC.
- Direct SQLite access in both production and local development.
- Local development uses `scripts/dev-normalization.sh` + Litestream restore to get fresh production snapshots without using GitHub quota.
