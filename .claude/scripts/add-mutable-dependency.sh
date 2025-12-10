#!/bin/bash

# Check if an argument was provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide a repository URL or path for the mutable dependency"
    echo "Usage: add-mutable-dependency <repository>"
    exit 1
fi

REPO="$1"
# Extract repo name from URL/path
REPO_NAME=$(basename "$REPO" .git)

# Clone the repository to lib/mutable
echo "Cloning mutable dependency: $REPO_NAME"
cd lib/mutable || exit 1
git clone "$REPO" "$REPO_NAME"

# Check if interfaces directory exists
if [ ! -d "$REPO_NAME/src/interfaces" ]; then
    echo "Error: No interfaces directory found in $REPO_NAME/src/"
    echo "Mutable dependencies must have an interfaces directory"
    rm -rf "$REPO_NAME"
    exit 1
fi

# Perform post-clone cleanup - keep only interfaces and their dependencies
echo "Cleaning up implementation details, keeping only interfaces..."
cd "$REPO_NAME" || exit 1

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

# Remove everything
find . -mindepth 1 -maxdepth 1 -exec rm -rf {} +

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

echo "Successfully added mutable dependency: $REPO_NAME"
echo "  - Interfaces: src/interfaces/"
if [ -d "lib/immutable" ]; then
    echo "  - External dependencies: lib/immutable/"
fi
