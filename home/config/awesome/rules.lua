local awful = require("awful")
local beautiful = require("beautiful")
local clientkeys = require("clientkeys")
local clientbuttons = require("clientbuttons")
local placement_rules = require("placement_rules")

require("globals")

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
    rule_any = { type = { "normal", "dialog" } },
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

  -- Assign clients to tags using role-based placement system

  -- Communication apps → external monitor (or ultrawide_left fallback)
  {
    rule = { class = "Signal" },
    callback = placement_rules.communication(TAGS[10])
  },
  {
    rule = { class = "Slack" },
    callback = placement_rules.communication(TAGS[10])
  },

  -- Development windows → ultrawide_right
  {
    rule = { class = "kitty", name = "spabreaks" },
    callback = placement_rules.development(TAGS[3])
  },
  {
    rule = { class = "kitty", name = ".*%-dev$" },
    callback = placement_rules.development(TAGS[1])
  },

  -- Secondary tasks → ultrawide_left
  {
    rule = { class = "kitty", name = ".*%-opencode$" },
    callback = placement_rules.secondary(TAGS[7])
  },

  -- System/admin → ultrawide_right
  {
    rule = { class = "kitty", name = ".*%-psql$" },
    callback = placement_rules.system(TAGS[13])
  },
  {
    rule = { class = "kitty", name = ".*%-console$" },
    callback = placement_rules.system(TAGS[13])
  },
}
