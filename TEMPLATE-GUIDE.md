# Tilt Template System - Developer Guide

This repository uses a template-based approach where a single `k8s.yaml` and `Tiltfile` can be reused across multiple applications by simply changing values in a `.env` file.

## Quick Start

1. **Copy the template files to your new app:**
   ```bash
   cp .env.example .env
   cp k8s.yaml your-app-dir/
   cp Tiltfile your-app-dir/
   ```

2. **Edit `.env` with your app-specific values:**
   ```bash
   APP_NAME=my-awesome-app
   CONTAINER_PORT=3000
   PORT_FORWARD=3000:3000
   ```

3. **Run Tilt:**
   ```bash
   tilt up
   ```

That's it! The template will automatically render with your values.

## How It Works

### Template Variables in k8s.yaml

The `k8s.yaml` file contains placeholders like `{{APP_NAME}}` that get replaced at runtime:

```yaml
metadata:
  name: {{APP_NAME}}        # Replaced with APP_NAME from .env
spec:
  replicas: {{REPLICAS}}    # Replaced with REPLICAS from .env
```

### Available Template Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `APP_NAME` | Application name | `python-example` | `my-api` |
| `CONTAINER_PORT` | Container port | `8080` | `3000` |
| `REPLICAS` | Number of replicas | `1` | `3` |
| `SECRET_NAME` | Auto-generated | `{APP_NAME}-secret` | `my-api-secret` |
| `NODE_SELECTOR` | Pin to specific node | `` | `docker001.ukatru.com` |
| `IMAGE_PULL_SECRET` | Image pull secret | `` | `ecr-creds` |

## Configuration Examples

### Example 1: Simple Web App

```bash
# .env
APP_NAME=web-frontend
CONTAINER_FILE=Dockerfile
CONTAINER_PORT=3000
PORT_FORWARD=3000:3000
REPLICAS=2

SECRET_DATABASE_URL=postgresql://localhost/webapp
SECRET_API_KEY=abc123
```

**Result:**
- Deployment name: `web-frontend`
- Secret name: `web-frontend-secret`
- 2 replicas
- Port 3000 exposed

### Example 2: API with ECR

```bash
# .env
APP_NAME=payment-api
CONTAINER_PORT=8080
PORT_FORWARD=8080:8080
NODE_SELECTOR=prod-node-01

USE_ECR=true
AWS_ACCOUNT_ID=123456789012
IMAGE_PULL_SECRET=ecr-creds

SECRET_STRIPE_KEY=sk_live_xxx
SECRET_DATABASE_URL=postgresql://prod.db/payments
```

**Result:**
- Deployment name: `payment-api`
- Pinned to node: `prod-node-01`
- Uses ECR with image pull secret
- Secrets auto-injected as env vars

### Example 3: Development vs Production

**dev/.env:**
```bash
APP_NAME=myapp-dev
REPLICAS=1
SECRET_DATABASE_URL=postgresql://localhost/dev
```

**prod/.env:**
```bash
APP_NAME=myapp-prod
REPLICAS=3
NODE_SELECTOR=prod-node
SECRET_DATABASE_URL=postgresql://prod.db/myapp
```

## Dynamic Secrets

Any environment variable starting with `SECRET_` is automatically added to Kubernetes secrets:

```bash
SECRET_DATABASE_URL=postgresql://...     → database-url
SECRET_API_KEY=abc123                    → api-key
SECRET_REDIS_PASSWORD=secret             → redis-password
```

These become environment variables in your pods (without the `SECRET_` prefix).

## Optional Features

### Node Selector

Pin your app to a specific node:

```bash
NODE_SELECTOR=docker001.ukatru.com
```

Leave empty to deploy on any node.

### Image Pull Secrets

For private registries:

```bash
IMAGE_PULL_SECRET=ecr-creds
```

### Skip Secret Creation

If your app doesn't need secrets:

```bash
CREATE_SECRETS=false
```

## Multi-Developer Workflow

Each developer can have their own `.env` file:

**alice/.env:**
```bash
APP_NAME=myapp-alice
PORT_FORWARD=8081:8080
```

**bob/.env:**
```bash
APP_NAME=myapp-bob
PORT_FORWARD=8082:8080
```

No conflicts! Each gets their own deployment and secrets.

## Template Rendering Process

1. Tilt reads your `.env` file
2. Loads template variables
3. Reads `k8s.yaml` template
4. Replaces all `{{VARIABLE}}` placeholders
5. Applies the rendered YAML to Kubernetes

## Best Practices

✅ **DO:**
- Keep `.env` in `.gitignore`
- Commit `.env.example` with dummy values
- Use descriptive `APP_NAME` values
- Prefix all secrets with `SECRET_`

❌ **DON'T:**
- Commit `.env` with real secrets
- Use the same `APP_NAME` as other developers
- Hardcode values in `k8s.yaml` or `Tiltfile`

## Troubleshooting

**Problem:** Variables not being replaced

**Solution:** Check that:
1. Variable is defined in `.env`
2. Placeholder uses correct syntax: `{{VARIABLE}}`
3. Tilt was restarted after changing `.env`

**Problem:** Secret not found

**Solution:** 
- Check `CREATE_SECRETS=true` in `.env`
- Verify `SECRET_` prefix on environment variables
- Check Tilt logs for secret creation messages

## Advanced: Custom Templates

You can create your own k8s.yaml template with additional placeholders:

```yaml
spec:
  template:
    spec:
      containers:
        - name: {{APP_NAME}}
          resources:
            limits:
              memory: {{MEMORY_LIMIT}}
              cpu: {{CPU_LIMIT}}
```

Then add to `.env`:
```bash
MEMORY_LIMIT=512Mi
CPU_LIMIT=500m
```

And update Tiltfile's `template_vars` dict to include them.
