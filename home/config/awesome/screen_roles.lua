-- Screen role identification based on geometry
-- This provides stable screen identification regardless of screen index order

local screen_roles = {}

-- Identify screen role based on geometry
-- Returns: "ultrawide_left", "ultrawide_right", "external", "primary", "secondary", or "ultrawide_single"
function screen_roles.identify_screen(s)
  local all_screens = {}

  -- Collect all screen geometries
  for scr in screen do
    table.insert(all_screens, {
      screen = scr,
      geo = scr.geometry,
      index = scr.index
    })
  end

  -- Sort screens by X position (left to right)
  table.sort(all_screens, function(a, b)
    return a.geo.x < b.geo.x
  end)

  -- Find pairs of screens that share the same Y coordinate and height
  -- These are likely fake screens from the same physical ultrawide monitor
  local ultrawide_pair = {}

  for i = 1, #all_screens do
    for j = i + 1, #all_screens do
      local scr1 = all_screens[i]
      local scr2 = all_screens[j]

      -- Check if screens share same Y and height (same physical monitor)
      if scr1.geo.y == scr2.geo.y and scr1.geo.height == scr2.geo.height then
        -- Check if they're adjacent or close in X position (split screens)
        local gap = math.abs((scr1.geo.x + scr1.geo.width) - scr2.geo.x)
        if gap < 10 then -- Allow small gap for rounding
          -- These are the split ultrawide screens
          -- Assign roles based on actual X position
          if scr1.geo.x < scr2.geo.x then
            ultrawide_pair = { left = scr1, right = scr2 }
          else
            ultrawide_pair = { left = scr2, right = scr1 }
          end
          break
        end
      end
    end
    if ultrawide_pair.left then break end
  end

  -- Determine role for this screen
  if ultrawide_pair.left then
    -- We found a split ultrawide
    if s.index == ultrawide_pair.left.index then
      return "ultrawide_left"
    elseif s.index == ultrawide_pair.right.index then
      return "ultrawide_right"
    else
      return "external"
    end
  elseif #all_screens == 1 then
    -- Single screen
    return "primary"
  else
    -- Multiple screens but no split detected
    -- Detect if screens are arranged vertically or horizontally
    local is_vertical = false

    -- Check if screens have significantly different Y positions vs X positions
    if #all_screens >= 2 then
      local y_diff = math.abs(all_screens[1].geo.y - all_screens[#all_screens].geo.y)
      local x_diff = math.abs(all_screens[1].geo.x - all_screens[#all_screens].geo.x)
      is_vertical = y_diff > x_diff
    end

    if is_vertical then
      -- Vertical arrangement: sort by Y position (top to bottom)
      table.sort(all_screens, function(a, b)
        return a.geo.y < b.geo.y
      end)
      -- Top screen (smallest Y) is primary
      if s.index == all_screens[1].index then
        return "primary"
      else
        return "secondary"
      end
    else
      -- Horizontal arrangement: use existing X sort (already sorted at line 21-23)
      -- Rightmost screen is primary (last in sorted list)
      if s.index == all_screens[#all_screens].index then
        return "primary"
      else
        return "secondary"
      end
    end
  end
end

-- Get all screens organized by role
function screen_roles.get_screen_layout()
  local layout = {
    ultrawide_left = nil,
    ultrawide_right = nil,
    external = nil,
    ultrawide_single = nil,
    primary = nil,
    secondary = nil,
  }

  for s in screen do
    local role = screen_roles.identify_screen(s)
    layout[role] = s
  end

  return layout
end

-- Get screen count for determining which tag configuration to use
function screen_roles.get_effective_screen_count()
  local layout = screen_roles.get_screen_layout()

  if layout.ultrawide_left and layout.ultrawide_right and layout.external then
    return 3
  elseif (layout.ultrawide_left and layout.ultrawide_right) or
      (layout.ultrawide_single and layout.external) or
      (layout.primary and layout.secondary) then
    return 2
  else
    return 1
  end
end

return screen_roles
