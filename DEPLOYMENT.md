# Deploying to Steam Deck - Quick Guide

## Prerequisites

### On Steam Deck (Desktop Mode):
1. Open Konsole terminal
2. Set a password for the 'deck' user:
   ```bash
   passwd
   ```
3. Enable and start SSH service:
   ```bash
   sudo systemctl enable sshd
   sudo systemctl start sshd
   ```
4. Get your Steam Deck's IP address:
   ```bash
   ip addr | grep 'inet '
   ```
   Look for something like `192.168.1.XXX` or `192.168.0.XXX`

## Deployment

### From Your Linux Desktop:

Run the deployment script with your Steam Deck's IP address:

```bash
./deploy-to-steamdeck.sh 192.168.1.XXX
```

Replace `192.168.1.XXX` with your actual Steam Deck IP address.

The script will:
- ✓ Test SSH connection
- ✓ Create application directory (`~/Applications/DeckImagePicker`)
- ✓ Transfer all application files
- ✓ Set executable permissions
- ✓ Create a desktop shortcut

## Running on Steam Deck

### Option 1: Desktop Shortcut (Easiest)
Double-click the "Deck Image Picker" icon on your Desktop

### Option 2: File Manager
1. Open Dolphin file manager
2. Navigate to `Applications/DeckImagePicker/`
3. Double-click `image_picker`

### Option 3: Terminal
```bash
~/Applications/DeckImagePicker/image_picker
```

## Usage

### Keyboard Shortcuts
- **P** or **Right Arrow** - Pick/mark image (green border)
- **X** or **Left Arrow** - Reject image (red border)
- **C** - Clear selection
- **Arrow Keys** - Navigate between images

### Workflow
1. Click "Select Folder" button
2. Choose a folder containing images
3. Use keyboard shortcuts to mark images as picked or rejected
4. Selections are auto-saved to `.deck-selections.json` in the image folder

## Optional: Add to Steam Library (for Gaming Mode)

1. In Desktop Mode, open Steam
2. Click **Games** → **Add a Non-Steam Game to My Library**
3. Click **Browse** and navigate to:
   `/home/deck/Applications/DeckImagePicker/image_picker`
4. Select it and click **Add Selected Programs**

### Controller Configuration (for Gaming Mode)
Since the app uses keyboard shortcuts, you'll need to map controller buttons:

Recommended mapping:
- **D-Pad / Left Stick** → Arrow keys
- **A Button** → P (Pick)
- **B Button** → X (Reject)
- **X Button** → C (Clear)

Configure this through Steam's Controller Configuration for this non-Steam game.

## Troubleshooting

### "Permission denied" when connecting
- Make sure you set a password: `passwd` on Steam Deck
- Ensure SSH is running: `sudo systemctl status sshd`

### "Cannot connect to Steam Deck"
- Verify the IP address is correct
- Make sure both devices are on the same network
- Try pinging the Steam Deck: `ping <steam-deck-ip>`

### Application won't launch
- Check permissions: `chmod +x ~/Applications/DeckImagePicker/image_picker`
- Try running from terminal to see error messages

### Missing GTK libraries
```bash
sudo pacman -S gtk3
```

## Updating the Application

To update after making changes:

1. Rebuild on your Linux desktop:
   ```bash
   flutter build linux --release
   ```

2. Re-run the deployment script:
   ```bash
   ./deploy-to-steamdeck.sh <steam-deck-ip>
   ```

The script will overwrite the existing installation with the new version.
