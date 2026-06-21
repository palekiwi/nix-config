---
status: complete
---
## Status: Complete

# Plan: Move Archived Items to Bottom and Change Display Style

We need to update `home/config/nvim/lua/config/utils/mem.lua` to:
1.  Treat `archived` status similarly to `done` for sorting purposes (move to the bottom).
2.  Display `archived` items in grey but without a strikethrough (unlike `done` items which have a strikethrough).

## Steps
1.  **Define `is_archived` helper**: Create a helper function to check if an artifact has `archived` status.
2.  **Update `is_done` helper**: Ensure `is_done` correctly identifies done items but NOT archived items if they are to be styled differently. Wait, `DONE_STATUSES` already includes `archived`.
3.  **Refactor `is_done` and `is_archived`**:
    *   `archived` is currently in `DONE_STATUSES`.
    *   `is_done` returns true if status is in `DONE_STATUSES`.
4.  **Update `sort_artifacts`**:
    *   Items that are either "done" or "archived" should go to the bottom.
5.  **Update `make_mem_entry_maker`**:
    *   Determine the highlight group based on whether it is "done" (strikethrough) or "archived" (grey).
6.  **Verify**: Open the picker and check sorting and styling.

## Proposed Changes
- In `is_done(artifact)`, keep it as is if we want "archived" to be considered "done" for sorting.
- However, we need to distinguish them for styling.

Let's look at `DONE_STATUSES`:
```lua
15: local DONE_STATUSES = {
16:   done = true,
17:   complete = true,
18:   closed = true,
19:   archived = true,
20: }
```

And `is_done`:
```lua
22: local function is_done(artifact)
23:   if not artifact.frontmatter or artifact.frontmatter == vim.NIL then
24:     return false
25:   end
26:   local status = artifact.frontmatter.status
27:   return status and type(status) == "string" and DONE_STATUSES[status:lower()] or false
28: end
```

The user said: "for entries with status `archived` put them to the bottom like those that have status done". This means both should be at the bottom.

"display the title in grey but without a strikethrough to distinguish them from done".

So I need a way to check for `archived` specifically.

```lua
local function is_archived(artifact)
  if not artifact.frontmatter or artifact.frontmatter == vim.NIL then
    return false
  end
  local status = artifact.frontmatter.status
  return status and type(status) == "string" and status:lower() == "archived" or false
end
```

And I should probably rename `DONE_STATUSES` to something like `COMPLETED_STATUSES` or similar if I want to use it for sorting both "done" and "archived". Actually, `is_done` currently includes `archived`.

If I keep `is_done` as it is (including `archived`), then the sorting logic:
```lua
424:     -- First: done items at the bottom
425:     local a_done = is_done(a)
426:     local b_done = is_done(b)
427:     if a_done ~= b_done then
428:       return not a_done
429:     end
```
...will already put `archived` items at the bottom.

But I need to distinguish them in `make_mem_entry_maker`:
```lua
344:       if is_done(entry) then
345:         highlight = "MemStatusDone"
346:       end
```
`MemStatusDone` likely has the strikethrough. I should probably introduce a `MemStatusArchived` highlight and check for archived status before `is_done` (if `is_done` still includes `archived`).

Better:
1.  Remove `archived` from `DONE_STATUSES`.
2.  Create `is_archived` function.
3.  Update sorting to use both.
4.  Update display to use both.

Wait, if I remove `archived` from `DONE_STATUSES`, I can make `is_done` strictly about "done/complete/closed".

Actually, let's see what `MemStatusDone` is. I'll search for where these highlights are defined (probably in some other file, but maybe I can see it in this one). It's not defined in this file.

I'll proceed with:
1.  Adding `is_archived` function.
2.  Removing `archived` from `DONE_STATUSES`.
3.  Updating `sort_artifacts` to treat both as "bottom-tier".
4.  Updating `make_mem_entry_maker` to use a different highlight for archived.

Wait, what is the highlight for grey? Probably `TelescopeResultsComment` or something similar, or I should define `MemStatusArchived`.

Actually, I should check if `MemStatusArchived` exists or if I should just use a standard one. Usually, "grey" in Telescope is `TelescopeResultsComment` or `Comment`.

Let's refine the plan.
1.  Modify `DONE_STATUSES` to remove `archived`.
2.  Add `is_archived(artifact)`.
3.  Update `sort_artifacts`.
4.  Update `make_mem_entry_maker`.

Wait, if I want `archived` to be at the bottom *with* `done`, I should probably have a `is_finished(artifact)` which is `is_done(artifact) or is_archived(artifact)`.

```lua
local function is_finished(artifact)
  return is_done(artifact) or is_archived(artifact)
end
```

Then sorting uses `is_finished`.
Display uses `is_archived` first, then `is_done`.

Wait, "grey but without a strikethrough". `MemStatusDone` probably has the strikethrough.

Let's check if there are other files that define these highlights.
