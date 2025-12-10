# add-mutable-dependency

Add a sibling submodule as a mutable dependency (interfaces only).

## Usage

```bash
.claude/scripts/add-mutable-dependency.sh <repository>
```

## Arguments

- `<repository>` (required): The git repository URL or path of the sibling submodule

## Description

This command adds a sibling submodule as a mutable dependency. Mutable dependencies are treated differently from immutable dependencies:

- Only interfaces and abstract contracts are exposed
- Implementation details are automatically removed
- Changes must go through the change request process
- Stored in `lib/mutable/`

## Examples

```bash
# Add a sibling submodule
.claude/scripts/add-mutable-dependency.sh ../phusd-oracle

# Add from a remote repository
.claude/scripts/add-mutable-dependency.sh https://github.com/org/sibling-submodule
```

## What It Does

1. Validates that a repository argument is provided
2. Clones the repository to `lib/mutable/<repo-name>`
3. Verifies the dependency has a `src/interfaces/` directory
4. Removes all implementation details, keeping only:
   - `src/interfaces/` - the public interfaces
   - `lib/immutable/` - external dependencies (e.g., OpenZeppelin) that interfaces may import
   - `foundry.toml` - needed for Foundry compilation
   - `remappings.txt` - needed for import resolution (if present)
5. Removes everything else: `.git/`, `test/`, `script/`, `lib/mutable/`, markdown files, etc.
6. If no interfaces directory exists, the dependency is removed and an error is shown

## Requirements

The target repository **must** have a `src/interfaces/` directory containing the public interfaces for the contract.

## Notes

- Implementation details are never available from mutable dependencies
- If you need changes to a mutable dependency, use the change request process documented in `MutableChangeRequests.json`
- To update an existing mutable dependency, use `update-mutable-dependency`
- `lib/immutable/` is preserved because interfaces may import from external libraries (e.g., `IERC20` from OpenZeppelin)
- `lib/mutable/` is removed to avoid recursive sibling dependencies - if a sibling's interface depends on another sibling, add that as a separate mutable dependency
