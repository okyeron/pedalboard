--- VolumePedal
-- @classmod VolumePedal

local ControlSpec = require "controlspec"
local UI = require "ui"

CONTROL_SPEC_MIX = ControlSpec.new(0, 100, "lin", 1, 50, "%")
CONTROL_SPEC_GAIN = ControlSpec.new(-60, 12, "lin", 0.5, 0, "dB")

local VolumePedal = {}
VolumePedal.__index = VolumePedal
VolumePedal.id = "volume"

function VolumePedal.new()
  local i = {}
  setmetatable(i, VolumePedal)

  -- TODO: make a superclass that has these as the default tabs, with default handlers for them, etc.
  i.tabs_table = {"Bypass & Mix", "In & Out Gains"}
  i.tabs = UI.Tabs.new(1, i.tabs_table)

  -- TODO: consider making bypass always an on/off label
  i.dial_bypass = UI.Dial.new(9, 12, 22, 0, 0, 1, 1)
  i.dial_mix = UI.Dial.new(34.5, 27, 22, 50, 0, 100, 1)
  i.dial_in_gain = UI.Dial.new(72, 12, 22, 0, -60, 12, 1, 0, {0})
  i.dial_out_gain = UI.Dial.new(97, 27, 22, 0, -60, 12, 1, 0, {0})
  i.dials = {{i.dial_bypass, i.dial_mix}, {i.dial_in_gain, i.dial_out_gain}}
  i:_update_active_dials()

  i.tab_bypass_label = ""
  i.tab_mix_dial = UI.Dial.new(0, 12, 22, 50, 0, 100, 1)

  i._param_id_to_dials = {}
  for layer_index, layer in ipairs(i._param_ids) do
    for index, param_id in ipairs(layer) do
      dial = i.dials[layer_index][index]
      i._param_id_to_dials[param_id] = dial
      i:_set_value_from_param_value(param_id, params:get(param_id))
    end
  end
  i:_add_param_actions()

  return i
end

function VolumePedal.name(short)
  return short and "VOL" or "Volume"
end

function VolumePedal.add_params()
  params:add_group(VolumePedal.name(), 4)

  id_prefix = VolumePedal.id

  bypass_id = id_prefix .. "_bypass"
  params:add({
    id = bypass_id,
    name = "Bypass",
    type = "option",
    options = {"Effect Enabled", "Bypassed"},
  })

  mix_id = id_prefix .. "_mix"
  params:add({
    id = mix_id,
    name = "Dry/Wet",
    type = "control",
    controlspec = CONTROL_SPEC_MIX,
  })

  in_gain_id = id_prefix .. "_in_gain"
  params:add({
    id = in_gain_id,
    name = "In Gain",
    type = "control",
    controlspec = CONTROL_SPEC_GAIN,
  })

  out_gain_id = id_prefix .. "_out_gain"
  params:add({
    id = out_gain_id,
    name = "Out Gain",
    type = "control",
    controlspec = CONTROL_SPEC_GAIN,
  })

  VolumePedal._param_ids = {{bypass_id, mix_id}, {in_gain_id, out_gain_id}}
end

function VolumePedal:_add_param_actions()
  for layer_index, layer in ipairs(self._param_ids) do
    for i, param_id in ipairs(layer) do
      params:set_action(param_id, function(value) self:_set_value_from_param_value(param_id, value) end)
    end
  end
end

function VolumePedal:enter()
  -- Called when the page is scrolled to
end

function VolumePedal:key(n, z)
  -- Key-up currently has no meaning
  if z ~= 1 then
    return false
  end

  -- Change the focused tab
  if n == 2 then
    direction = -1
  elseif n == 3 then
    direction = 1
  end
  self.tabs:set_index_delta(direction, false)
  self:_update_active_dials()

  return true
end

function VolumePedal:enc(n, delta)
  -- Change the value of a focused dial
  dial_index = n - 1
  param_id = self._param_ids[self.tabs.index][dial_index]
  params:delta(param_id, delta)
  return true
end

function VolumePedal:redraw()
  self.tabs:redraw()
  for tab_index, tab in ipairs(self.dials) do
    for dial_index, dial in ipairs(tab) do
      dial:redraw()
    end
  end
  screen.move(64, 64)
  screen.text_center(self.name())
end

function VolumePedal:render_as_tab(offset, width, is_active)
  center_x = offset + (width / 2)
  tab_mix_dial_value = self.tab_mix_dial.value
  self.tab_mix_dial = UI.Dial.new(center_x - 11, 16, 22, tab_mix_dial_value, 0, 100, 1)
  self.tab_mix_dial.active = is_active
  self.tab_mix_dial:redraw()
  if self.tab_bypass_label == "ON" then
    screen.level(is_active and 15 or 6)
  else
    screen.level(is_active and 4 or 1)
  end
  screen.move(center_x, 56)
  screen.text_center(self.tab_bypass_label)
  screen.level(15)
  -- Prevent a stray line being drawn
  screen.stroke()
end

function VolumePedal:_set_value_from_param_value(param_id, value)
  coerced_value = value
  if param_id == "volume_bypass" then
    -- The options are 1-indexed, but the bypass control expects 0 or 1
    coerced_value = value - 1
    self.tab_bypass_label = value == 1 and "ON" or "OFF"
  elseif param_id == "volume_mix" then
    self.tab_mix_dial:set_value(coerced_value)
  end
  self._param_id_to_dials[param_id]:set_value(coerced_value)

  -- Tell the engine what you did.
  if param_id == "volume_bypass" then
    engine.volume_bypass(coerced_value)
  elseif param_id == "volume_mix" then
    engine.volume_mix(coerced_value / 100.0)
  elseif param_id == "volume_in_gain" then
    engine.volume_in_gain(util.dbamp(coerced_value))
  elseif param_id == "volume_out_gain" then
    engine.volume_out_gain(util.dbamp(coerced_value))
  end
end

function VolumePedal:_update_active_dials()
  current_tab_index = self.tabs.index
  for tab_index, tab in ipairs(self.dials) do
    for dial_index, dial in ipairs(tab) do
      dial.active = tab_index == current_tab_index
    end
  end
end

return VolumePedal