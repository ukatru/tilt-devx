# Tilt Templates ConfigMap - Deployment Guide

This guide explains how to deploy the Tilt templates as a ConfigMap for use in Coder workspaces.

## Overview

The templates are packaged as a Kubernetes ConfigMap that gets mounted into developer workspaces at `/apps/template`. Developers can then easily copy these templates to start new projects.

## Deployment

### 1. Deploy the ConfigMap

```bash
kubectl apply -f tilt-templates-configmap.yaml
```

Verify it was created:
```bash
kubectl get configmap tilt-templates
kubectl describe configmap tilt-templates
```

### 2. Mount in Coder Workspace (Example)

Add this to your Coder workspace template or Pod specification:

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
    - name: tilt-templates
      mountPath: /apps/template
      readOnly: true
  volumes:
  - name: tilt-templates
    configMap:
      name: tilt-templates
```

### 3. Verify Templates are Available

Inside the workspace:
```bash
ls -la /apps/template/
# Should show: Tiltfile, k8s.yaml, .env.example, README.md
```

## Usage for Developers

### Option 1: Using the Helper Script

If you include the `init-tilt-project.sh` script in your workspace image:

```bash
# Initialize in current directory
init-tilt-project.sh

# Or specify a directory
init-tilt-project.sh ~/my-new-app
```

### Option 2: Manual Copy

```bash
# Create your project directory
mkdir ~/my-app
cd ~/my-app

# Copy templates
cp /apps/template/Tiltfile ./
cp /apps/template/k8s.yaml ./
cp /apps/template/.env.example .env

# Edit configuration
vim .env

# Start developing
tilt up
```

## What's Included in the ConfigMap

| File | Description |
|------|-------------|
| `Tiltfile` | Main Tilt configuration with template rendering |
| `k8s.yaml` | Kubernetes deployment template |
| `.env.example` | Example environment configuration |
| `README.md` | User documentation |

## ConfigMap Structure

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tilt-templates
data:
  Tiltfile: |
    # Full Tiltfile content...
  k8s.yaml: |
    # Full k8s.yaml template...
  .env.example: |
    # Full .env.example...
  README.md: |
    # Full README...
```

## Updating Templates

When you need to update the templates:

1. Edit the source files (Tiltfile, k8s.yaml, etc.)
2. Regenerate the ConfigMap:
   ```bash
   # Update tilt-templates-configmap.yaml with new content
   kubectl apply -f tilt-templates-configmap.yaml
   ```
3. Existing workspaces will get updated templates on next pod restart
4. Or force refresh:
   ```bash
   kubectl rollout restart deployment/coder-workspaces
   ```

## Integration with Coder

### Example Coder Template

```hcl
resource "kubernetes_config_map" "tilt_templates" {
  metadata {
    name      = "tilt-templates"
    namespace = var.namespace
  }

  data = {
    "Tiltfile"     = file("${path.module}/templates/Tiltfile")
    "k8s.yaml"     = file("${path.module}/templates/k8s.yaml")
    ".env.example" = file("${path.module}/templates/.env.example")
    "README.md"    = file("${path.module}/templates/README.md")
  }
}

resource "kubernetes_pod" "workspace" {
  # ... other configuration ...

  spec {
    container {
      # ... other configuration ...
      
      volume_mount {
        name       = "tilt-templates"
        mount_path = "/apps/template"
        read_only  = true
      }
    }

    volume {
      name = "tilt-templates"
      config_map {
        name = kubernetes_config_map.tilt_templates.metadata[0].name
      }
    }
  }
}
```

### Workspace Initialization Script

Add to your workspace startup script:

```bash
#!/bin/bash
# ~/.config/coder/startup.sh

# Check if templates are available
if [ -d "/apps/template" ]; then
  echo "✅ Tilt templates available at /apps/template"
  echo "   Run 'init-tilt-project.sh' to start a new project"
else
  echo "⚠️  Tilt templates not found"
fi
```

## Best Practices

1. **Version Control**: Keep the ConfigMap YAML in git alongside your Coder templates
2. **Namespace**: Deploy to the same namespace as your workspaces
3. **Read-Only**: Always mount as read-only to prevent accidental modifications
4. **Documentation**: Include the README.md in the ConfigMap for self-service
5. **Updates**: Use CI/CD to automatically update the ConfigMap when templates change

## Troubleshooting

**Templates not visible in workspace:**
- Check ConfigMap exists: `kubectl get cm tilt-templates`
- Verify mount in pod: `kubectl describe pod <workspace-pod>`
- Check permissions: `ls -la /apps/template`

**Old templates showing:**
- ConfigMap updates require pod restart
- Delete and recreate the workspace pod
- Or use `kubectl rollout restart`

**Permission denied:**
- Ensure ConfigMap is mounted as read-only
- Check workspace pod security context

## Example Developer Workflow

```bash
# 1. Developer starts workspace (templates auto-mounted at /apps/template)

# 2. Create new project
cd ~/projects
mkdir my-api
cd my-api

# 3. Initialize from templates
init-tilt-project.sh

# 4. Configure app
vim .env
# Set APP_NAME=my-api
# Set CONTAINER_PORT=3000
# Add SECRET_DATABASE_URL=...

# 5. Create Dockerfile
cat > Dockerfile.simple << EOF
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
EOF

# 6. Start development
tilt up

# 7. Code, test, iterate!
```

## Security Considerations

- ConfigMap data is **not encrypted** - don't put real secrets here
- Templates should only contain example/placeholder values
- Real secrets go in developer's `.env` file (gitignored)
- Consider RBAC to control who can modify the ConfigMap

## Maintenance

Regular tasks:
- Review and update templates quarterly
- Collect developer feedback
- Test templates with new Tilt versions
- Update documentation as features change
