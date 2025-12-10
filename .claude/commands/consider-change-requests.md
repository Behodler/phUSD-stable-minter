# consider-change-requests

Review and implement incoming change requests from sibling submodules.

## Usage

```bash
.claude/scripts/consider-change-requests.sh
```

## Arguments

None required.

## Description

This command displays incoming change requests from sibling submodules that need modifications to this submodule's interfaces. These requests are stored in `SiblingChangeRequests.json` and are populated by the parent repository's `pop-change-requests` script.

## What It Does

1. Checks if `SiblingChangeRequests.json` exists
2. If found, displays the contents of pending change requests
3. Prompts to review and implement the requested changes using TDD principles

## Workflow

When this command shows pending requests:

1. **Review** each change request carefully
2. **Write tests first** following TDD principles
3. **Implement** the requested interface changes
4. **Document** any requests that cannot be implemented
5. **Commit** your changes to make them available to sibling submodules

## Example Request Format

```json
{
  "requests": [
    {
      "from": "requesting-submodule",
      "changes": [
        {
          "fileName": "ISomeInterface.sol",
          "description": "Add method X to handle Y"
        }
      ]
    }
  ]
}
```

## Notes

- Always follow TDD principles when implementing changes
- If a request cannot be fulfilled, document the reason for the requesting submodule
- After implementing changes, sibling submodules need to run `update-mutable-dependency` to pull the updates
