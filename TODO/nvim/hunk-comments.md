# Hunk Comments

---

## Description

Given a JSON file containing AI-generated comments about git diff hunks, display the relevant comment in a floating window based on the cursor position.

## Example JSON

```json
{
  "version": "1.0",
  "commit_sha": "abc123...",
  "generated_at": "2025-10-14T10:30:00Z",
  "hunks": [
    {
      "id": "hunk_1",
      "file": "src/services/process.ts",
      "line_start": 712,
      "line_end": 725,
      "change_type": "logic",
      "comment": "Adds retry logic with exponential backoff when connection fails",
      "diff": "@@ -712,5 +712,8 @@ function connectToServer() {\n-  const result = await fetch(url);\n+  let retries = 0;\n+  while (retries < 3) {\n+    try {\n+      const result = await fetch(url);\n+      break;\n+    } catch (error) {\n+      retries++;\n+      await new Promise(resolve => setTimeout(resolve, Math.pow(2, retries) * 1000));\n+    }\n+  }"
    },
    {
      "id": "hunk_2",
      "file": "src/views/dashboard.erb",
      "line_start": 45,
      "line_end": 48,
      "change_type": "formatting",
      "comment": "Formatting only: Line break added after opening tag",
      "diff": "@@ -45,3 +45,4 @@ <div class=\"header\">\n-<div class=\"title\">Dashboard</div>\n+\n+<div class=\"title\">Dashboard</div>"
    }
  ]
}
```

## Example code

```lua
function show_hunk_comment()
   local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
   local current_file = vim.fn.expand('%:p')  -- absolute path
   local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
   local relative_path = current_file:sub(#git_root + 2)  -- remove git root prefix

   -- Read JSON (from HEAD or configured commit)
   local json_path = git_root .. '/.git/hunk-comments/HEAD.json'
   local json_content = vim.fn.readfile(json_path)
   local data = vim.fn.json_decode(table.concat(json_content))

   -- Find matching hunk
   for _, hunk in ipairs(data.hunks) do
     if hunk.file == relative_path and
        cursor_line >= hunk.line_start and
        cursor_line <= hunk.line_end then
       show_floating_window(hunk.comment, hunk.change_type)
       return
     end
   end

   print("No hunk comment at cursor")
 end
```
