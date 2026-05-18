# Reaper Quad Cortex MIDI Helper

A GUI helper tool for automating **Neural DSP Quad Cortex** presets and scenes inside **Reaper**.

Instead of manually programming MIDI events in the MIDI editor, this script allows you to quickly select:

- MIDI channel
- preset folder
- preset bank
- preset slot (A–H)
- scene (A–H)

…and automatically insert the correct MIDI commands at the edit cursor.

---

# Features

- Easy-to-use GUI panel
- Quad Cortex preset selection
- Quad Cortex scene selection
- Automatic calculation of:
  - CC0
  - CC32
  - Program Change
  - CC43
- Smart insertion logic
- Optional overwrite mode
- Visual preview of inserted MIDI values
- Works directly in Reaper’s MIDI editor

---

# Requirements

## Reaper

Download Reaper:

https://reaper.fm

---

## ReaPack

Install ReaPack:

https://reapack.com

---

## ReaImGui

This script requires:

ReaImGui: ReaScript binding for Dear ImGui

Install it via:

Extensions ? ReaPack ? Browse Packages

Search for:

ReaImGui

Install it and restart Reaper.

---

# Installation

1. Download the `.lua` script file
2. In Reaper, open:

Actions ? Show Action List

3. Click:

New Action ? Load ReaScript

4. Select the script file

5. Optional: add the script to a toolbar
   - Right-click toolbar
   - Customize toolbar
   - Add
   - Search for the script
   - Add it

---

# Important Usage Notes

- The script works on the active MIDI editor
- Make sure the correct MIDI item is selected
- Place the edit cursor where the MIDI commands should be inserted

---

# Quad Cortex MIDI Mapping

The script uses the following MIDI commands:

| Function | MIDI |
|---|---|
| Preset Folder | CC32 |
| Bank MSB | CC0 |
| Preset Selection | Program Change |
| Scene Selection | CC43 |

---

# Preset Logic

Quad Cortex presets are calculated as:

    preset_index = (bank - 1) * 8 + slot

Example:

    2B

means:

    Bank 2 + Slot B

---

# Auto Insert

Optional auto-insert mode allows commands to be written automatically when selections are changed.

---

# Overwrite Mode

Overwrite mode deletes existing Quad Cortex MIDI commands near the edit cursor before inserting new ones.

Only these MIDI messages are affected:

- CC0
- CC32
- Program Change
- CC43

MIDI notes are NOT deleted.

---

# Preview

The preview section displays:

- selected preset
- selected scene
- raw MIDI values

before insertion.


---

# License

MIT License

---

# Disclaimer

This script is an unofficial community tool and is not affiliated with Neural DSP.
