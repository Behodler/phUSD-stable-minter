# update-mutable-dependency

Pull the latest changes for a mutable dependency.

## Usage

```bash
.claude/scripts/update-mutable-dependency.sh <dependency-name>
```

## Arguments

- `<dependency-name>` (required): The name of the mutable dependency to update (must exist in `lib/mutable/`)

## Description

This command updates an existing mutable dependency to pull the latest interface changes. Use this after a sibling submodule has implemented your change requests.

## Examples

```bash
# Update the phusd-oracle dependency
.claude/scripts/update-mutable-dependency.sh phusd-oracle

# Update another sibling dependency
.claude/scripts/update-mutable-dependency.sh price-feed
```

## What It Does

1. Validates the dependency name is provided
2. Verifies the dependency exists in `lib/mutable/`
3. Reverts any local changes to restore all files
4. Pulls the latest changes from the remote
5. Verifies the updated dependency still has a `src/interfaces/` directory
6. Removes implementation details, keeping only:
   - `src/interfaces/` - the public interfaces
   - `lib/immutable/` - external dependencies (e.g., OpenZeppelin) that interfaces may import
   - `foundry.toml` - needed for Foundry compilation
   - `remappings.txt` - needed for import resolution (if present)
   - `.git/` - needed for future updates

## Workflow

After submitting a change request:

1. Wait for the target submodule to implement your requested changes
2. Run this command to pull the updated interfaces
3. Continue development with the new interface definitions

## Notes

- This command will discard any local modifications in the dependency
- Only interfaces and external dependencies are retained after the update
- The dependency must have a valid `src/interfaces/` directory
- If the interfaces directory is missing after update, an error is shown
- `lib/immutable/` is preserved because interfaces may import from external libraries (e.g., `IERC20` from OpenZeppelin)
- `lib/mutable/` is removed to avoid recursive sibling dependencies
