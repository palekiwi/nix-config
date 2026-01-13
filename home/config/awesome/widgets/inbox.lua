local wibox = require("wibox")
local gears = require("gears")

require("widgets.config")

---@class InboxWidget.Colors
---@field fg_active string
---@field bg_active string
---@field fg_inactive string
---@field bg_inactive string

---@class InboxWidget.Opts
---@field colors? InboxWidget.Colors
---@field dir? string
---@field term string
---@field timeout? number

local inbox = {}

local default_colors = {
  bg_important = "#cc6666",
  fg_active    = "#1d1d1f",
  bg_active    = "#f0c674",
  fg_inactive  = "#1d1d1f",
  bg_inactive  = "#666666"
}

---@param term string
---@return number
local function count_by(term)
  local count = 0
  local cmd = "notmuch count " .. term
  local handle = io.popen(cmd)

  if handle then
    count = tonumber(handle:read("*a")) or 0
    handle:close()
  end

  return count
end

---@param opts? InboxWidget.Opts
function inbox.create(opts)
  opts = opts or {}
  local colors = opts.colors or default_colors
  local timeout = opts.timeout or 10

  local HOME = os.getenv("HOME")
  local radius = 2

  local icon_path = HOME .. "/.nix-profile/share/icons/Arc/status/symbolic/mail-unread-symbolic.svg"

  ---@param text? string
  ---@param fg_color? string
  local function span(text, fg_color)
    text = text or "0"
    fg_color = fg_color or colors.fg_inactive

    return '<span weight="bold" foreground="' .. fg_color .. '">' .. text .. '</span>'
  end

  local inbox_text_widget = wibox.widget {
    markup = span(),
    widget = wibox.widget.textbox
  }

  local important_text_widget = wibox.widget {
    markup = span(),
    widget = wibox.widget.textbox
  }

  local staging_text_widget = wibox.widget {
    markup = span(),
    widget = wibox.widget.textbox
  }

  local production_text_widget = wibox.widget {
    markup = span(),
    widget = wibox.widget.textbox
  }

  local icon_widget = wibox.widget {
    image = gears.color.recolor_image(icon_path, colors.fg_active),
    resize = true,
    widget = wibox.widget.imagebox
  }

  local inbox_content = wibox.widget {
    layout = wibox.layout.fixed.horizontal,
    spacing = 4,
    icon_widget,
    inbox_text_widget
  }

  local inbox_widget = wibox.widget {
    inbox_content,
    left = 4,
    right = 4,
    top = 1,
    bottom = 1,
    widget = wibox.container.margin
  }

  local airbrake_production = wibox.widget {
    production_text_widget,
    left = 4,
    right = 4,
    top = 1,
    bottom = 1,
    widget = wibox.container.margin
  }

  local important_widget = wibox.widget {
    important_text_widget,
    left = 4,
    right = 4,
    top = 1,
    bottom = 1,
    widget = wibox.container.margin
  }

  local airbrake_staging = wibox.widget {
    staging_text_widget,
    left = 4,
    right = 4,
    top = 1,
    bottom = 1,
    widget = wibox.container.margin
  }

  local inbox_widget_outer_left = wibox.widget {
    inbox_widget,
    bg = colors.bg_inactive,
    shape = function(cr, width, height)
      gears.shape.partially_rounded_rect(cr, width, height, true, false, false, true, radius)
    end,
    widget = wibox.container.background
  }

  local inbox_widget_inner_1 = wibox.widget {
    important_widget,
    bg = colors.bg_inactive,
    shape = gears.shape.rectangle,
    widget = wibox.container.background
  }

  local inbox_widget_inner_2 = wibox.widget {
    airbrake_production,
    bg = colors.bg_inactive,
    shape = gears.shape.rectangle,
    widget = wibox.container.background
  }

  local inbox_widget_outer_right = wibox.widget {
    airbrake_staging,
    bg = colors.bg_inactive,
    shape = function(cr, width, height)
      gears.shape.partially_rounded_rect(cr, width, height, false, true, true, false, radius)
    end,
    widget = wibox.container.background
  }

  local function update()
    local countImp = count_by('tag:unread AND tag:"!"')
    local countInbox = count_by('tag:unread AND tag:"inbox"')
    local countAP = count_by('tag:unread AND tag:"airbrake/production"')
    local countAS = count_by('tag:unread AND tag:"airbrake/staging"')

    local activeImportant = countImp > 0
    local activeInbox = countInbox > 0
    local activeAP = countAP > 0
    local activeAS = countAS > 0

    local fg_color_imp = activeImportant and colors.fg_active or colors.fg_inactive
    local bg_color_imp = activeImportant and colors.bg_important or colors.bg_inactive
    local fg_color = activeInbox and colors.fg_active or colors.fg_inactive
    local bg_color = activeInbox and colors.bg_active or colors.bg_inactive
    local fg_color_ap = activeAP and colors.fg_active or colors.fg_inactive
    local bg_color_ap = activeAP and colors.bg_active or colors.bg_inactive
    local fg_color_as = activeAS and colors.fg_active or colors.fg_inactive
    local bg_color_as = activeAS and colors.bg_active or colors.bg_inactive

    local icon = gears.color.recolor_image(icon_path, fg_color)

    inbox_text_widget.markup = span(tostring(countInbox), fg_color)
    inbox_widget_outer_left.bg = bg_color
    icon_widget.image = icon

    inbox_widget_inner_1.bg = bg_color_imp
    important_text_widget.markup = span(tostring(countImp), fg_color_imp)

    inbox_widget_inner_2.bg = bg_color_ap
    production_text_widget.markup = span(tostring(countAP), fg_color_ap)

    inbox_widget_outer_right.bg = bg_color_as
    staging_text_widget.markup = span(tostring(countAS), fg_color_as)
  end

  update()

  gears.timer {
    timeout = timeout,
    autostart = true,
    callback = update
  }

  return wibox.widget {
    wibox.widget {
      layout = wibox.layout.fixed.horizontal,
      spacing = 1,
      inbox_widget_outer_left,
      inbox_widget_inner_1,
      inbox_widget_inner_2,
      inbox_widget_outer_right
    },
    margins = MARGINS,
    widget = wibox.container.margin
  }
end

return inbox
