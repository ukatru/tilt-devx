#!/bin/bash
# create-common-secret.sh
# Helper script to create a common secret shared across all developer apps

set -e

SECRET_NAME="common-secret"
NAMESPACE="${1:-default}"

echo "🔐 Creating common secret: $SECRET_NAME in namespace: $NAMESPACE"
echo ""
echo "This secret will be shared across all your apps."
echo "Add key-value pairs that you want available in all applications."
echo ""

# Collect secret data
declare -A secrets

echo "Enter secret key-value pairs (press Ctrl+D when done):"
echo "Format: KEY=VALUE"
echo ""

while IFS='=' read -r key value; do
  if [ -n "$key" ] && [ -n "$value" ]; then
    secrets["$key"]="$value"
    echo "  ✓ Added: $key"
  fi
done

if [ ${#secrets[@]} -eq 0 ]; then
  echo ""
  echo "❌ No secrets provided. Exiting."
  exit 1
fi

# Build kubectl command
CMD="kubectl create secret generic $SECRET_NAME --namespace=$NAMESPACE"

for key in "${!secrets[@]}"; do
  CMD="$CMD --from-literal=$key=${secrets[$key]}"
done

# Create the secret
echo ""
echo "Creating secret..."
eval "$CMD"

echo ""
echo "✅ Common secret created successfully!"
echo ""
echo "📝 To use this secret in your apps, add to .env:"
echo "   COMMON_SECRET_NAME=$SECRET_NAME"
echo ""
echo "🔍 View secret:"
echo "   kubectl get secret $SECRET_NAME -n $NAMESPACE"
echo ""
echo "🗑️  Delete secret:"
echo "   kubectl delete secret $SECRET_NAME -n $NAMESPACE"
