#!/bin/bash

# Build TriggerX SDK in isolation to avoid TypeScript conflicts

set -e

echo "🔨 Building TriggerX SDK..."

cd node_modules/sdk-triggerx

# Create a temporary tsconfig that excludes parent project
cat > tsconfig.build.json << 'EOF'
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "rootDir": "./src",
    "outDir": "./dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "../**/*", "../../**/*"]
}
EOF

# Build with the isolated config
npx tsc --project tsconfig.build.json

# Clean up temp config
rm -f tsconfig.build.json

cd ../..

if [ -f "node_modules/sdk-triggerx/dist/index.js" ]; then
    echo "SUCCESS: SDK built successfully!"
else
    echo "ERROR: Build failed - dist/index.js not found"
    exit 1
fi

