#!/bin/bash
# init-tilt-project.sh
# Helper script to initialize a new Tilt project from templates

set -e

TEMPLATE_DIR="${TEMPLATE_DIR:-/apps/template}"
PROJECT_DIR="${1:-.}"

echo "🚀 Initializing Tilt project in: $PROJECT_DIR"

# Check if template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "❌ Error: Template directory not found at $TEMPLATE_DIR"
  echo "   Make sure the tilt-templates ConfigMap is mounted in your workspace"
  exit 1
fi

# Create project directory if it doesn't exist
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Copy template files
echo "📋 Copying template files..."

if [ -f "$TEMPLATE_DIR/Tiltfile" ]; then
  cp "$TEMPLATE_DIR/Tiltfile" ./Tiltfile
  echo "  ✓ Tiltfile"
else
  echo "  ⚠ Tiltfile not found in template directory"
fi

if [ -f "$TEMPLATE_DIR/k8s.yaml" ]; then
  cp "$TEMPLATE_DIR/k8s.yaml" ./k8s.yaml
  echo "  ✓ k8s.yaml"
else
  echo "  ⚠ k8s.yaml not found in template directory"
fi

if [ -f "$TEMPLATE_DIR/.env.example" ]; then
  cp "$TEMPLATE_DIR/.env.example" ./.env
  echo "  ✓ .env (from .env.example)"
else
  echo "  ⚠ .env.example not found in template directory"
fi

if [ -f "$TEMPLATE_DIR/README.md" ]; then
  cp "$TEMPLATE_DIR/README.md" ./TILT-README.md
  echo "  ✓ TILT-README.md"
fi

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
  cat > .gitignore << 'EOF'
# Environment variables - contains secrets
.env

# Tilt temporary files
.tiltbuild/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
*.egg-info/
dist/
build/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/
EOF
  echo "  ✓ .gitignore"
fi

echo ""
echo "✅ Tilt project initialized successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Edit .env file with your app configuration:"
echo "      vim .env"
echo ""
echo "   2. Update these key values:"
echo "      - APP_NAME=your-app-name"
echo "      - CONTAINER_PORT=your-port"
echo "      - Add SECRET_* variables for your secrets"
echo ""
echo "   3. Create your Dockerfile (e.g., Dockerfile.simple)"
echo ""
echo "   4. Start Tilt:"
echo "      tilt up"
echo ""
echo "📖 For more information, see TILT-README.md"
