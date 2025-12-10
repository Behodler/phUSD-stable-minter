#!/bin/bash

# Check if an argument was provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide the name of the mutable dependency to update"
    echo "Usage: update-mutable-dependency <dependency-name>"
    exit 1
fi

DEP_NAME="$1"
DEP_PATH="lib/mutable/$DEP_NAME"

# Check if dependency exists
if [ ! -d "$DEP_PATH" ]; then
    echo "Error: Mutable dependency '$DEP_NAME' not found in lib/mutable/"
    exit 1
fi

cd "$DEP_PATH" || exit 1

# Revert any changes to restore deleted files
echo "Reverting local changes to restore all files..."
git checkout .
git clean -fd

# Pull latest changes
echo "Pulling latest changes..."
git pull

# Check if interfaces directory exists
if [ ! -d "src/interfaces" ]; then
    echo "Error: No interfaces directory found in updated $DEP_NAME/src/"
    echo "Mutable dependencies must have an interfaces directory"
    exit 1
fi

# Clean up again - keep only interfaces and their dependencies
echo "Cleaning up implementation details, keeping only interfaces..."

# Save items we need to keep
TEMP_DIR="/tmp/mutable_dep_temp_$$"
mkdir -p "$TEMP_DIR"

# Save interfaces
if [ -d "src/interfaces" ]; then
    cp -r src/interfaces "$TEMP_DIR/interfaces"
fi

# Save immutable dependencies (external libs like OpenZeppelin that interfaces may import)
if [ -d "lib/immutable" ]; then
    cp -r lib/immutable "$TEMP_DIR/lib_immutable"
fi

# Save foundry.toml (needed for compilation)
if [ -f "foundry.toml" ]; then
    cp foundry.toml "$TEMP_DIR/foundry.toml"
fi

# Save remappings.txt if present (needed for import resolution)
if [ -f "remappings.txt" ]; then
    cp remappings.txt "$TEMP_DIR/remappings.txt"
fi

# Remove everything except .git (needed for future updates)
find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

# Restore only what we need
mkdir -p src lib

if [ -d "$TEMP_DIR/interfaces" ]; then
    mv "$TEMP_DIR/interfaces" src/interfaces
fi

if [ -d "$TEMP_DIR/lib_immutable" ]; then
    mv "$TEMP_DIR/lib_immutable" lib/immutable
fi

if [ -f "$TEMP_DIR/foundry.toml" ]; then
    mv "$TEMP_DIR/foundry.toml" foundry.toml
fi

if [ -f "$TEMP_DIR/remappings.txt" ]; then
    mv "$TEMP_DIR/remappings.txt" remappings.txt
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo "Successfully updated mutable dependency: $DEP_NAME"
echo "  - Interfaces: src/interfaces/"
if [ -d "lib/immutable" ]; then
    echo "  - External dependencies: lib/immutable/"
fi
