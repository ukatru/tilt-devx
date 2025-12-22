# Tiltfile Template Usage

This Tiltfile is designed as a reusable template that can be configured via environment variables in a `.env` file.

## Quick Start

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your app-specific values

3. Run Tilt:
   ```bash
   tilt up
   ```

## Configuration Variables

### App Configuration
- `APP_NAME` - Name of your application (default: `python-example`)
  - **Note:** Secret name is automatically set to `{APP_NAME}-secrets`
- `CONTAINER_FILE` - Dockerfile to use (default: `Dockerfile.simple`)
- `K8S_YAML_FILE` - Kubernetes manifest file (default: `k8s.yaml`)
- `PORT_FORWARD` - Port forwarding configuration (default: `8080:8787`)
- `CREATE_SECRETS` - Create secrets from env vars (default: `true`)

### Registry Configuration
- `DOCKER_REGISTRY` - Docker registry to use (default: `docker.io/ukatru`)
- `USE_ECR` - Enable AWS ECR login (default: `false`)
- `AWS_ACCOUNT_ID` - AWS account ID for ECR
- `AWS_REGION` - AWS region for ECR (default: `us-west-2`)

### Dynamic Secrets
Any environment variable starting with `SECRET_` will automatically be added to the Kubernetes secret.

**Example:**
```bash
SECRET_DATABASE_URL=postgresql://user:pass@localhost/db
SECRET_API_KEY=abc123
SECRET_REDIS_PASSWORD=secret
```

These become:
- `database-url` in the secret
- `api-key` in the secret
- `redis-password` in the secret

## Example .env Files

### Example 1: Simple Python App
```bash
APP_NAME=my-python-app
CONTAINER_FILE=Dockerfile
PORT_FORWARD=5000:5000

# Secret will be created as: my-python-app-secrets
SECRET_DATABASE_URL=postgresql://localhost/mydb
SECRET_API_KEY=test-key
```

### Example 2: Using ECR
```bash
APP_NAME=production-api
USE_ECR=true
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1

SECRET_DATABASE_URL=postgresql://prod.db/api
SECRET_JWT_SECRET=super-secret
```

### Example 3: Multiple Apps in Same Repo
Each developer can have different `.env` files:

**alice/.env:**
```bash
APP_NAME=api-alice
PORT_FORWARD=8081:8080
SECRET_DATABASE_URL=postgresql://localhost/alice_db
```

**bob/.env:**
```bash
APP_NAME=api-bob
PORT_FORWARD=8082:8080
SECRET_DATABASE_URL=postgresql://localhost/bob_db
```

## Benefits

✅ **Single Tiltfile** - Works for all apps and developers  
✅ **No hardcoded values** - Everything configurable via `.env`  
✅ **Dynamic secrets** - Just prefix with `SECRET_` to add to k8s secret  
✅ **No conflicts** - Each developer can use unique resource names  
✅ **ECR support** - Optional AWS ECR authentication  
✅ **Git-friendly** - `.env` in `.gitignore`, `.env.example` committed  

## Tips

1. **Never commit `.env`** - Add it to `.gitignore`
2. **Commit `.env.example`** - With dummy/example values
3. **Use different APP_NAME per developer** - Avoid resource conflicts
4. **Prefix secrets with SECRET_** - Automatic secret injection
