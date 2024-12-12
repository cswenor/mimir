#!/bin/bash
set -e

echo "Starting initialization..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Node.js is required but not installed. Please install Node.js first."
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    npm install
fi

# Generate .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Generating .env file..."
    node scripts/generate-env.js
fi

# Generate required files using values from .env
echo "Generating required files..."
node scripts/generate-files.js

echo "Initialization complete!"