# add-immutable-dependency

Add an external library as an immutable dependency.

## Usage

```bash
.claude/scripts/add-immutable-dependency.sh <repository>
```

## Arguments

- `<repository>` (required): The git repository URL or path to clone

## Description

This command adds an external library (such as OpenZeppelin) as an immutable dependency. Unlike mutable dependencies, immutable dependencies:

- Have full source code available
- Are not expected to change based on sibling submodule requirements
- Are stored in `lib/immutable/`

## Examples

```bash
# Add OpenZeppelin contracts
.claude/scripts/add-immutable-dependency.sh https://github.com/OpenZeppelin/openzeppelin-contracts

# Add a local repository
.claude/scripts/add-immutable-dependency.sh ../some-local-lib
```

## What It Does

1. Validates that a repository argument is provided
2. Extracts the repository name from the URL/path
3. Clones the full repository to `lib/immutable/<repo-name>`

## Notes

- The entire repository is cloned with full source code access
- Use this for external dependencies that won't need modification
- For sibling submodule dependencies, use `add-mutable-dependency` instead
