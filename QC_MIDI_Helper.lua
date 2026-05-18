--[[
Quad Cortex MIDI Helper Panel (ReaImGui)
+ Overwrite toggle
+ Smart insert memory fix
+ More obvious selected A-H buttons

Active MIDI editor take only.
]]

local reaper = reaper

if not reaper.ImGui_CreateContext then
  reaper.MB(
    "ReaImGui not available.\nInstall 'ReaImGui: ReaScript binding for Dear ImGui' via ReaPack and restart Reaper.",
    "Quad Cortex MIDI Helper", 0
  )
  return
end

local ctx = reaper.ImGui_CreateContext('Quad Cortex MIDI Helper')
local font = reaper.ImGui_CreateFont('sans-serif', 14)
reaper.ImGui_Attach(ctx, font)

local chan_ui = 1

local folder_labels = { "Factory (CC32=0)", "My Presets (CC32=1)" }
local folder_vals   = { 0, 1 }
local folder_idx = 2

local bank_ui = 1
local preset_slot_ui = 0
local scene_ui = 0

local names = { "A","B","C","D","E","F","G","H" }

local auto_insert_on_change = false

local overwrite_qc_near_cursor = false
local overwrite_all_channels = false
local overwrite_tolerance_ppq = 0

local last = { chan=nil, cc0=nil, cc32=nil, pc=nil, cc43=nil }

local function get_active_midi_take()
  local me = reaper.MIDIEditor_GetActive()
  if not me then return nil end
  local take = reaper.MIDIEditor_GetTake(me)
  if not take or not reaper.TakeIsMIDI(take) then return nil end
  return take
end

local function ppq_at_edit_cursor(take)
  local t = reaper.GetCursorPosition()
  return reaper.MIDI_GetPPQPosFromProjTime(take, t)
end

local function insert_cc(take, ppq, chan0, cc_num, cc_val)
  reaper.MIDI_InsertCC(take, false, false, ppq, 0xB0, chan0, cc_num, cc_val)
end

local function insert_pc(take, ppq, chan0, program)
  reaper.MIDI_InsertCC(take, false, false, ppq, 0xC0, chan0, program, 0)
end

local function compute_messages()
  local preset_index = (bank_ui - 1) * 8 + preset_slot_ui
  local cc0_val = math.floor(preset_index / 128)
  local pc_val  = preset_index % 128
  local cc32_val = folder_vals[folder_idx]
  return preset_index, cc0_val, cc32_val, pc_val, scene_ui
end

local function reset_memory()
  last.chan, last.cc0, last.cc32, last.pc, last.cc43 = nil, nil, nil, nil, nil
end

local function delete_qc_msgs_near_cursor(take, chan0, ppq_base)
  local deleted_count = 0
  local tol = overwrite_tolerance_ppq or 0

  local function ppq_match(ppq_evt, ppq_target)
    return math.abs(ppq_evt - ppq_target) <= tol
  end

  local targets = {
    ppq_base - 2,
    ppq_base - 1,
    ppq_base,
    ppq_base + 1
  }

  local _, _, ccs = reaper.MIDI_CountEvts(take)

  for i = ccs - 1, 0, -1 do
    local ok, _, _, ppqpos, chanmsg, ch, msg2, _ = reaper.MIDI_GetCC(take, i)
    if ok then
      local channel_ok = overwrite_all_channels or (ch == chan0)

      if channel_ok then
        local is_cc0  = (chanmsg == 0xB0 and msg2 == 0)
        local is_cc32 = (chanmsg == 0xB0 and msg2 == 32)
        local is_cc43 = (chanmsg == 0xB0 and msg2 == 43)
        local is_pc   = (chanmsg == 0xC0)

        if is_cc0 or is_cc32 or is_cc43 or is_pc then
          for _, tppq in ipairs(targets) do
            if ppq_match(ppqpos, tppq) then
              reaper.MIDI_DeleteCC(take, i)
              deleted_count = deleted_count + 1
              break
            end
          end
        end
      end
    end
  end

  return deleted_count
end

local function insert_if_needed(take)
  local _, cc0_val, cc32_val, pc_val, cc43_val = compute_messages()

  local desired = {
    chan = chan_ui - 1,
    cc0  = cc0_val,
    cc32 = cc32_val,
    pc   = pc_val,
    cc43 = cc43_val
  }

  local ppq = ppq_at_edit_cursor(take)
  local ppq_cc0  = math.max(0, ppq - 2)
  local ppq_cc32 = math.max(0, ppq - 1)
  local ppq_pc   = ppq
  local ppq_cc43 = ppq + 1

  if overwrite_qc_near_cursor then
    local deleted = delete_qc_msgs_near_cursor(take, desired.chan, ppq)

    -- Only reset smart memory if something was actually overwritten.
    if deleted > 0 then
      reset_memory()
    end
  end

  local chan_changed = (last.chan ~= nil and desired.chan ~= last.chan)

  local preset_changed =
    (last.cc0 ~= nil and desired.cc0 ~= last.cc0) or
    (last.cc32 ~= nil and desired.cc32 ~= last.cc32) or
    (last.pc ~= nil and desired.pc ~= last.pc) or
    (last.cc0 == nil or last.cc32 == nil or last.pc == nil)

  local force_all = chan_changed
  local force_preset = preset_changed or force_all

  local scene_changed = (last.cc43 == nil or desired.cc43 ~= last.cc43)

  if force_preset then
    insert_cc(take, ppq_cc0,  desired.chan, 0,  desired.cc0)
    insert_cc(take, ppq_cc32, desired.chan, 32, desired.cc32)
    insert_pc(take, ppq_pc,   desired.chan, desired.pc)
    last.cc0, last.cc32, last.pc = desired.cc0, desired.cc32, desired.pc
  end

  if force_all or scene_changed then
    insert_cc(take, ppq_cc43, desired.chan, 43, desired.cc43)
    last.cc43 = desired.cc43
  end

  last.chan = desired.chan
  reaper.MIDI_Sort(take)
end

local function ah_buttons(unique_id_prefix, current_index, set_fn)
  local clicked = false

  for row = 0, 1 do
    for col = 0, 3 do
      local i = row * 4 + col
      local is_sel = (current_index == i)

      if is_sel then
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 6)
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1)

        -- More obvious selected button colour
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x4A90E2FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x5AA0F2FF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x3A80D2FF)
      end

      local label = names[i+1] .. "##" .. unique_id_prefix .. "_" .. names[i+1]

      if reaper.ImGui_Button(ctx, label, 48, 28) then
        set_fn(i)
        clicked = true
      end

      if is_sel then
        reaper.ImGui_PopStyleColor(ctx, 3)
        reaper.ImGui_PopStyleVar(ctx, 2)
      end

      if col < 3 then reaper.ImGui_SameLine(ctx) end
    end
  end

  return clicked
end

local function loop()
  reaper.ImGui_SetNextWindowSize(ctx, 640, 460, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Quad Cortex MIDI Helper', true,
    reaper.ImGui_WindowFlags_AlwaysAutoResize())

  if visible then
    local take = get_active_midi_take()

    reaper.ImGui_Text(ctx, 'Important: always select the MIDI item that needs the QC commands.\nSelect a preset and scene, then insert them at the edit cursor.')
    reaper.ImGui_Separator(ctx)

    if not take then
      local col = reaper.ImGui_ColorConvertDouble4ToU32(1, 0.6, 0.2, 1)
      reaper.ImGui_TextColored(ctx, col, 'No active MIDI editor take detected.')
      reaper.ImGui_Text(ctx, 'Open a MIDI item in the MIDI editor, then run this script again.')
      reaper.ImGui_End(ctx)
      if open then reaper.defer(loop) end
      return
    end

    local rv
    rv, chan_ui = reaper.ImGui_SliderInt(ctx, 'MIDI Channel', chan_ui, 1, 16)

    if reaper.ImGui_BeginCombo(ctx, 'Folder (CC32)', folder_labels[folder_idx]) then
      for i = 1, #folder_labels do
        local selected = (i == folder_idx)
        if reaper.ImGui_Selectable(ctx, folder_labels[i], selected) then
          folder_idx = i
          if auto_insert_on_change then
            reaper.Undo_BeginBlock()
            insert_if_needed(take)
            reaper.Undo_EndBlock('QC MIDI Helper: Insert (auto)', -1)
          end
        end
        if selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
      end
      reaper.ImGui_EndCombo(ctx)
    end

    reaper.ImGui_Separator(ctx)

    reaper.ImGui_Text(ctx, 'Preset bank (row)')
    if reaper.ImGui_Button(ctx, '-##bank', 32, 26) then
      bank_ui = math.max(1, bank_ui - 1)
      if auto_insert_on_change then
        reaper.Undo_BeginBlock(); insert_if_needed(take); reaper.Undo_EndBlock('QC MIDI Helper: Insert (auto)', -1)
      end
    end

    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, '+##bank', 32, 26) then
      bank_ui = math.min(32, bank_ui + 1)
      if auto_insert_on_change then
        reaper.Undo_BeginBlock(); insert_if_needed(take); reaper.Undo_EndBlock('QC MIDI Helper: Insert (auto)', -1)
      end
    end

    reaper.ImGui_SameLine(ctx)
    rv, bank_ui = reaper.ImGui_SliderInt(ctx, '##bank_slider', bank_ui, 1, 32)

    reaper.ImGui_Spacing(ctx)

    reaper.ImGui_Text(ctx, 'Preset slot (A–H)')
    local changed_preset = ah_buttons("preset", preset_slot_ui, function(i) preset_slot_ui = i end)

    reaper.ImGui_Spacing(ctx)

    reaper.ImGui_Text(ctx, 'Scene (CC43) (A–H)')
    local changed_scene = ah_buttons("scene", scene_ui, function(i) scene_ui = i end)

    reaper.ImGui_Separator(ctx)

    rv, auto_insert_on_change = reaper.ImGui_Checkbox(ctx, 'Auto-insert when I change selections', auto_insert_on_change)

    rv, overwrite_qc_near_cursor = reaper.ImGui_Checkbox(ctx, 'Overwrite QC msgs near cursor (delete existing CC0/CC32/PC/CC43 first)', overwrite_qc_near_cursor)

    if overwrite_qc_near_cursor then
      rv, overwrite_all_channels = reaper.ImGui_Checkbox(ctx, 'Overwrite on ALL MIDI channels (otherwise only selected channel)', overwrite_all_channels)
      reaper.ImGui_Text(ctx, 'Overwrite only removes QC control messages. Notes are not deleted.')
    end

    local preset_index, cc0_val, cc32_val, pc_val, cc43_val = compute_messages()

    reaper.ImGui_Text(ctx, 'Preview (what will be inserted):')
    reaper.ImGui_BulletText(ctx, string.format('Ch %d | CC32=%d | CC0=%d | PC=%d | CC43=%d', chan_ui, cc32_val, cc0_val, pc_val, cc43_val))
    reaper.ImGui_BulletText(ctx, string.format('Preset %d%s (preset_index=%d) | Scene %s',
      bank_ui, names[preset_slot_ui+1], preset_index, names[scene_ui+1]))

    reaper.ImGui_Spacing(ctx)

    if reaper.ImGui_Button(ctx, 'Insert at Cursor', 200, 34) then
      reaper.Undo_BeginBlock()
      insert_if_needed(take)
      reaper.Undo_EndBlock('QC MIDI Helper: Insert preset + scene', -1)
    end

    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, 'Reset memory', 140, 34) then
      reset_memory()
    end

    if auto_insert_on_change and (changed_preset or changed_scene) then
      reaper.Undo_BeginBlock()
      insert_if_needed(take)
      reaper.Undo_EndBlock('QC MIDI Helper: Insert (auto)', -1)
    end

    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
