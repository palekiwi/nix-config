local awful = require("awful")
local beautiful = require("beautiful")
local clientkeys = require("clientkeys")
local clientbuttons = require("clientbuttons")

local function on_second_screen(tag_name)
  return function(c)
    local target_screen = screen[2] or screen[1]

    -- Find the tag by name
    local target_tag = nil
    for _, tag in ipairs(target_screen.tags) do
      if tag.name == tag_name then
        target_tag = tag
        break
      end
    end

    if target_tag then
      c:move_to_tag(target_tag)
    end
  end
end

awful.rules.rules = {
  -- All clients will match this rule.
  {
    rule = {},
    properties = {
      border_width = beautiful.border_width,
      size_hints_honor = false,
      border_color = beautiful.border_normal,
      focus = awful.client.focus.filter,
      raise = true,
      keys = clientkeys,
      buttons = clientbuttons,
      screen = awful.screen.preferred,
      placement = awful.placement.no_overlap + awful.placement.no_offscreen
    }
  },

  -- Floating clients.
  {
    rule_any = {
      instance = {
        "pinentry",
      },
      class = {
        -- "Signal",
      },
      name = {
        "Event Tester", -- xev.
      },
      role = {
        -- "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
      }
    },
    properties = { floating = true }
  },

  -- Add titlebars to normal clients and dialogs
  {
    rule_any = { type = { "normal", "dialog" }
    },
    properties = { titlebars_enabled = false }
  },

  {
    rule = { class = "firefox" },
    properties = { maximized = false }
  },

  {
    rule = { class = "Gcr-prompter" },
    properties = {
      placement = awful.placement.centered + awful.placement.no_overlap +
          awful.placement.no_offscreen
    }
  },

  -- Assign clients to tags
  { callback = on_second_screen("〇"), rule = { class = "Signal" } },
  { callback = on_second_screen("〇"), rule = { class = "Slack" } },
  { callback = on_second_screen("七"), rule = { class = "Claude" } },
  { callback = on_second_screen("丙"), rule = { class = "Virt-manager" } },
  {
    rule = { class = "kitty", name = "spabreaks" },
    properties = { screen = screen[1], tag = screen[1].tags[3] }
  },
  {
    rule = { class = "kitty", name = ".*%-dev$" },
    properties = { screen = screen[1], tag = screen[1].tags[1] }
  },
  {
    rule = { class = "kitty", name = "ava%-.*$" },
    callback = on_second_screen("九"),
  },
  {
    rule = { class = "kitty", name = ".*%-psql$" },
    properties = { screen = screen[1], tag = "丙" }
  },
  {
    rule = { class = "kitty", name = ".*%-console$" },
    properties = { screen = screen[1], tag = "丙" }
  },
}
