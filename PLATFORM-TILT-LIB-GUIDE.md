# Platform-Managed Tilt Library - Deployment Guide

This guide explains how to deploy and manage `tilt_lib.star` as a platform-managed ConfigMap controlled by ArgoCD.

## Overview

The Tilt library (`tilt_lib.star`) is distributed via Kubernetes ConfigMap and mounted into developer workspaces. This allows the platform team to:

- ✅ Centrally manage Tilt helper functions
- ✅ Push updates to all developers automatically
- ✅ Enforce standards and best practices
- ✅ Version control via ArgoCD/GitOps

## Architecture

```
┌─────────────────┐
│  Platform Team  │
│   (GitOps Repo) │
└────────┬────────┘
         │
         │ ArgoCD syncs
         ▼
┌─────────────────────┐
│  tilt-lib ConfigMap │
│  (Kubernetes)       │
└────────┬────────────┘
         │
         │ Mounted at /apps/tilt-lib/
         ▼
┌─────────────────────┐
│ Developer Workspace │
│  (Coder Pod)        │
└─────────────────────┘
```

## Deployment Steps

### 1. Deploy the ConfigMap

```bash
# Apply the ConfigMap
kubectl apply -f tilt-lib-configmap.yaml

# Verify it was created
kubectl get configmap tilt-lib
kubectl describe configmap tilt-lib
```

### 2. Mount in Developer Workspaces

Add to your Coder workspace template or Pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: developer-workspace
spec:
  containers:
  - name: workspace
    image: your-workspace-image
    volumeMounts:
    - name: tilt-lib
      mountPath: /apps/tilt-lib
      readOnly: true
    - name: tilt-templates  # Optional: also mount Tilt templates
      mountPath: /apps/template
      readOnly: true
  volumes:
  - name: tilt-lib
    configMap:
      name: tilt-lib
  - name: tilt-templates
    configMap:
      name: tilt-templates  # From previous setup
```

### 3. Developers Use Platform Library

Developers' Tiltfile automatically loads from the mounted location:

```python
# Tiltfile loads from /apps/tilt-lib/ if available
# Falls back to local ./tilt_lib.star for local development
```

## ArgoCD Integration

### Application Manifest

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tilt-lib
  namespace: argocd
spec:
  project: platform-tools
  source:
    repoURL: https://github.com/your-org/platform-tools
    targetRevision: main
    path: tilt-lib
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Directory Structure in Git

```
platform-tools/
├── tilt-lib/
│   └── tilt-lib-configmap.yaml
└── tilt-templates/
    └── tilt-templates-configmap.yaml
```

## Updating the Library

### Via GitOps (Recommended)

1. Update `tilt_lib.star` content in `tilt-lib-configmap.yaml`
2. Commit and push to Git
3. ArgoCD automatically syncs the change
4. Existing workspaces get updated on next pod restart
5. Or force refresh: `kubectl rollout restart deployment/coder-workspaces`

### Manual Update (Testing)

```bash
# Edit the ConfigMap
kubectl edit configmap tilt-lib

# Or apply updated file
kubectl apply -f tilt-lib-configmap.yaml
```

## Developer Experience

### Initial Setup

```bash
# Developer starts workspace - tilt_lib.star is already mounted

# Copy Tiltfile template
cp /apps/template/Tiltfile ./

# The Tiltfile automatically uses platform library
tilt up
```

### Local Override (for testing)

Developers can test local changes:

```bash
# Copy platform library locally
cp /apps/tilt-lib/tilt_lib.star ./

# Modify locally
vim tilt_lib.star

# Tiltfile will use local copy (./tilt_lib.star takes precedence)
tilt up
```

## Versioning Strategy

### Semantic Versioning in ConfigMap

Add version label:

```yaml
metadata:
  name: tilt-lib
  labels:
    version: "1.2.0"
    app: tilt-lib
```

### Multiple Versions (Advanced)

Support multiple versions simultaneously:

```yaml
# tilt-lib-v1
apiVersion: v1
kind: ConfigMap
metadata:
  name: tilt-lib-v1
data:
  tilt_lib.star: |
    # Version 1.x

---
# tilt-lib-v2
apiVersion: v1
kind: ConfigMap
metadata:
  name: tilt-lib-v2
data:
  tilt_lib.star: |
    # Version 2.x
```

Developers specify version in workspace:

```yaml
volumes:
- name: tilt-lib
  configMap:
    name: tilt-lib-v2  # Pin to specific version
```

## Monitoring & Observability

### Check Library Version

```bash
# In workspace
cat /apps/tilt-lib/tilt_lib.star | head -n 5

# Check ConfigMap version
kubectl get configmap tilt-lib -o jsonpath='{.metadata.labels.version}'
```

### Track Usage

Add metrics to track which workspaces are using the library:

```python
# In tilt_lib.star
print('Using platform tilt_lib version: 1.2.0')
```

## Rollback Procedure

### Via ArgoCD

```bash
# Rollback to previous version
argocd app rollback tilt-lib

# Or via Git
git revert <commit-hash>
git push
```

### Manual Rollback

```bash
# Apply previous version
kubectl apply -f tilt-lib-configmap.yaml.backup
```

## Best Practices

1. **Version Everything** - Tag releases in Git
2. **Test Before Deploy** - Test in dev namespace first
3. **Communicate Changes** - Notify developers of breaking changes
4. **Gradual Rollout** - Use canary deployments for major changes
5. **Keep Backwards Compatible** - Avoid breaking changes when possible
6. **Document Changes** - Maintain CHANGELOG.md

## Troubleshooting

**Library not found:**
```bash
# Check if ConfigMap exists
kubectl get configmap tilt-lib

# Check if mounted in workspace
ls -la /apps/tilt-lib/

# Check pod volumes
kubectl describe pod <workspace-pod>
```

**Old version loading:**
```bash
# Restart workspace to get latest
kubectl delete pod <workspace-pod>

# Or force ConfigMap refresh
kubectl rollout restart deployment/coder-workspaces
```

**Local override not working:**
```bash
# Check load order in Tiltfile
# Local ./tilt_lib.star should take precedence
ls -la ./tilt_lib.star
```

## Security Considerations

- ConfigMap is mounted **read-only** - developers can't modify it
- Platform team controls updates via GitOps
- RBAC controls who can modify the ConfigMap
- Audit trail via Git history

## Example: Complete Workflow

```bash
# Platform Team
git clone https://github.com/your-org/platform-tools
cd platform-tools/tilt-lib
vim tilt-lib-configmap.yaml  # Update library
git commit -m "feat: add new helper function"
git push
# ArgoCD auto-deploys

# Developer (automatic)
# Workspace restarts and gets new version
tilt up  # Uses latest platform library
```

## Migration Path

### From Local to Platform-Managed

1. Developers currently use local `tilt_lib.star`
2. Deploy ConfigMap with same content
3. Update Tiltfile to check mounted location first
4. Developers' existing setup continues to work
5. Gradually remove local copies

No disruption to developer workflow!
