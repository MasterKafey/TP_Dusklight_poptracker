# Twilight Princess (Dusklight) Tracker
A PopTracker pack for **Twilight Princess (Dusklight)** in Archipelago, ported from
[Kizugaya's TPRAP_poptracker](https://github.com/Kizugaya/TPRAP_poptracker).
You can get the actual PopTracker program from [here](https://github.com/black-sliver/PopTracker/releases/latest).

## Install
Download the zip from the [latest release](https://github.com/MasterKafey/TP_Dusklight_poptracker/releases),
put it (unzipped or not) in PopTracker's `packs` folder, open the pack and pick a "Standard Archipelago
Tracker" variant. Connect with the AP button (server, slot name, password): items, checks and the
seed's settings are tracked automatically. PopTracker offers updates on its own.
# Credits
Big Thanks to [AudioPixie](https://github.com/AudioPixie) and [Darkzant](https://github.com/darkzant) for letting me use their assets

# Dusklight port
This fork targets the **Twilight Princess (Dusklight)** apworld (`tp_dusklight.apworld`) instead of the emulator one.
Item and location ids are generated from the apworld:

```
python tools/gen_mappings.py path/to/tp_dusklight.apworld
```

`tools/data/item_codes.json` (apworld item name -> tracker code) and `tools/data/location_paths.json`
(apworld location name -> tracker section) are the sources; `scripts/item_mapping.lua` and
`scripts/location_mapping.lua` are generated from them. Rerun the script after an apworld update.

## Logic
Location logic comes from the apworld's own world graph (the randomizer's YAML logic):

```
python tools/gen_logic.py path/to/tp_dusklight.apworld
```

writes `scripts/logic_data.lua` and points every check's section at `$DLAccess|<location name>`.
`scripts/logic.lua` evaluates it like the apworld does (human/wolf and day/night per area, twilight,
events, items the randomizer leaves in place) using the slot's settings from slot_data.
Run `gen_mappings.py` then `gen_logic.py` after each apworld update.
