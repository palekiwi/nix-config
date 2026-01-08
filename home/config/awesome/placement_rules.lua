local screen_roles = require("screen_roles")

local placement_rules = {}

-- Helper: Find a screen by role with fallback support
local function find_screen_by_role(role, fallback_role)
  local layout = screen_roles.get_screen_layout()

  if layout[role] then
    return layout[role]
  end

  if fallback_role and layout[fallback_role] then
    return layout[fallback_role]
  end

  return layout.ultrawide_right or layout.primary or screen.primary
end

-- Helper: Find a tag on a screen by name
local function find_tag_on_screen(scr, tag_name)
  if not scr or not scr.tags then
    return nil
  end

  for _, tag in ipairs(scr.tags) do
    if tag.name == tag_name then
      return tag
    end
  end

  return nil
end

-- Core function: Place a window on a specific screen role and tag
-- Returns a callback function suitable for use in awful.rules
--
-- config table:
--   preferred_role: First choice screen role (e.g., "external", "ultrawide_left")
--   fallback_role: Second choice screen role (optional)
--   tag: Tag name to place on (required)
--
-- Example:
--   {
--     rule = { class = "Signal" },
--     callback = placement_rules.place_on({
--       preferred_role = "external",
--       fallback_role = "ultrawide_left",
--       tag = "乙"
--     })
--   }
function placement_rules.place_on(config)
  return function(c)
    local target_screen = find_screen_by_role(config.preferred_role, config.fallback_role)
    local target_tag = find_tag_on_screen(target_screen, config.tag)

    if target_tag then
      c:move_to_tag(target_tag)
    end
  end
end

-- Preset: Communication apps (Signal, Slack, etc.)
-- Prefers: external → ultrawide_left → primary
function placement_rules.communication(tag_name)
  return placement_rules.place_on({
    preferred_role = "ultrawide_left",
    fallback_role = "primary",
    tag = tag_name
  })
end

-- Preset: Development windows (terminal, editors, dev tools)
-- Prefers: ultrawide_right → primary
function placement_rules.development(tag_name)
  return placement_rules.place_on({
    preferred_role = "ultrawide_right",
    fallback_role = "primary",
    tag = tag_name
  })
end

-- Preset: Secondary tasks (tools, monitoring, etc.)
-- Prefers: ultrawide_left → primary
function placement_rules.secondary(tag_name)
  return placement_rules.place_on({
    preferred_role = "ultrawide_left",
    fallback_role = "primary",
    tag = tag_name
  })
end

-- Preset: System/admin tasks (databases, consoles, system tools)
-- Prefers: ultrawide_right → primary
function placement_rules.system(tag_name)
  return placement_rules.place_on({
    preferred_role = "ultrawide_right",
    fallback_role = "primary",
    tag = tag_name
  })
end

return placement_rules
