# Twilight Princess Tracker
This is a pack for PopTracker Twilight Princess with Archipelago integration.
You can get the actual PopTracker program from [here](https://github.com/black-sliver/PopTracker/releases/latest).
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
