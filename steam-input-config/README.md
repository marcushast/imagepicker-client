# Steam Input Configuration for Deck Image Picker

This directory contains the Steam Input configuration file for optimal Steam Deck controller support.

## What This Does

The `deck-imagepicker.vdf` configuration file maps the Steam Deck's back buttons (L4/L5/R4/R5) to keyboard shortcuts, since these buttons are not accessible through standard gamepad APIs.

## Button Mappings

### Back Buttons (L4/L5/R4/R5)
- **L4** → `P` key (Pick image and advance to next)
- **L5** → `Up Arrow` key (Pick image without advancing)
- **R4** → `X` key (Reject image and advance to next)
- **R5** → `Down Arrow` key (Reject image without advancing)

### Trackpads
- **Left Trackpad** → D-Pad emulation (for navigation)
- **Right Trackpad** → Mouse emulation (for clicking UI buttons)

### Standard Controls
All standard gamepad buttons (face buttons, D-pad, sticks, triggers, bumpers) work natively through the application's gamepad support and don't require this configuration.

## How to Import This Configuration

### Method 1: Via Steam (Gaming Mode or Desktop Mode)

1. **Add Deck Image Picker as a Non-Steam Game:**
   - Open Steam in Desktop Mode
   - Go to **Games** → **Add a Non-Steam Game to My Library**
   - Browse to the application executable (e.g., `~/Applications/DeckImagePicker/image_picker`)
   - Click **Add Selected Programs**

2. **Import the Configuration:**
   - Right-click on "Deck Image Picker" in your Steam library
   - Select **Properties** → **Controller** → **Edit Layout**
   - Click the settings icon (⚙️) → **Browse Configs**
   - Select **Import Config** from the bottom menu
   - Navigate to this file: `steam-input-config/deck-imagepicker.vdf`
   - Select it and confirm the import

3. **Apply the Configuration:**
   - After importing, the configuration should be automatically applied
   - You can verify it's active by checking the controller layout shows "Deck Image Picker - Steam Deck Configuration"

### Method 2: Manual File Copy (Advanced)

If the import method doesn't work, you can manually copy the configuration to Steam's config directory:

```bash
# Find your Steam installation config directory (usually):
STEAM_CONFIG="$HOME/.steam/steam/userdata/<YOUR_STEAM_ID>/config/controller_configs/"

# Copy the configuration file
cp deck-imagepicker.vdf "$STEAM_CONFIG/"
```

## Testing the Configuration

After importing:

1. Launch the Deck Image Picker through Steam
2. Load a folder with images
3. Test the back buttons:
   - Press **L4** - should pick the current image and advance
   - Press **L5** - should pick the current image without advancing
   - Press **R4** - should reject the current image and advance
   - Press **R5** - should reject the current image without advancing

## Customizing the Configuration

You can customize the button mappings through Steam's controller configuration UI:

1. Right-click the game in Steam → **Properties** → **Controller** → **Edit Layout**
2. Select any input (like "Back Button L4")
3. Choose a different keyboard key or gamepad button
4. Save your changes

Your custom configuration will be saved separately and won't be overwritten.

## Troubleshooting

**Problem:** Back buttons don't work
**Solution:** Make sure you're launching the app through Steam (as a Non-Steam Game) with the configuration active. Back buttons only work when Steam Input is active.

**Problem:** Can't find the VDF file to import
**Solution:** Make sure you're browsing to the full path: `/home/deck/Applications/DeckImagePicker/steam-input-config/deck-imagepicker.vdf` (adjust the path if you installed it elsewhere)

**Problem:** Configuration isn't being applied
**Solution:** Try restarting Steam, or manually activate the configuration in the controller settings.

## Native Gamepad Support

Remember: The application has full native gamepad support for all standard buttons:
- Face buttons (A/B/X/Y)
- D-Pad
- Left and right sticks
- Triggers (LT/RT)
- Bumpers (LB/RB)
- Select and Start buttons

**Only the back buttons (L4/L5/R4/R5) require this Steam Input configuration.**

For a complete list of controls, press the **Y button** or **Start button** while the app is running to see the help dialog.
