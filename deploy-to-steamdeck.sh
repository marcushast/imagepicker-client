#!/bin/bash
# Deploy Deck Image Picker to Steam Deck via SSH
# Usage: ./deploy-to-steamdeck.sh <steam-deck-ip>

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STEAM_DECK_IP="$1"
STEAM_DECK_USER="deck"
APP_NAME="DeckImagePicker"
REMOTE_APP_DIR="/home/deck/Applications/${APP_NAME}"
LOCAL_BUNDLE_DIR="build/linux/x64/release/bundle"

# Check arguments
if [ -z "$STEAM_DECK_IP" ]; then
    echo -e "${RED}Error: Steam Deck IP address required${NC}"
    echo "Usage: $0 <steam-deck-ip>"
    echo ""
    echo "To find your Steam Deck IP:"
    echo "  1. Open Konsole on Steam Deck (Desktop Mode)"
    echo "  2. Run: ip addr | grep 'inet '"
    echo "  3. Look for an IP like 192.168.x.x"
    exit 1
fi

# Check if bundle exists
if [ ! -d "$LOCAL_BUNDLE_DIR" ]; then
    echo -e "${RED}Error: Build bundle not found at $LOCAL_BUNDLE_DIR${NC}"
    echo "Run 'flutter build linux --release' first"
    exit 1
fi

echo -e "${GREEN}=== Deploying Deck Image Picker to Steam Deck ===${NC}"
echo "Steam Deck IP: $STEAM_DECK_IP"
echo "Remote directory: $REMOTE_APP_DIR"
echo ""

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ! ssh -o ConnectTimeout=5 "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "echo 'Connection successful'" 2>/dev/null; then
    echo -e "${RED}Error: Cannot connect to Steam Deck${NC}"
    echo ""
    echo "Make sure you have:"
    echo "  1. Set a password on Steam Deck: passwd"
    echo "  2. Enabled SSH: sudo systemctl enable sshd && sudo systemctl start sshd"
    echo "  3. Correct IP address"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Steam Deck${NC}"
echo ""

# Create remote directory
echo -e "${YELLOW}Creating application directory on Steam Deck...${NC}"
ssh "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "mkdir -p ${REMOTE_APP_DIR}"
echo -e "${GREEN}✓ Directory created${NC}"
echo ""

# Transfer bundle
echo -e "${YELLOW}Transferring application files (this may take a minute)...${NC}"
rsync -avz --progress "${LOCAL_BUNDLE_DIR}/" "${STEAM_DECK_USER}@${STEAM_DECK_IP}:${REMOTE_APP_DIR}/"
echo -e "${GREEN}✓ Files transferred${NC}"
echo ""

# Make executable
echo -e "${YELLOW}Setting executable permissions...${NC}"
ssh "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "chmod +x ${REMOTE_APP_DIR}/image_picker"
echo -e "${GREEN}✓ Permissions set${NC}"
echo ""

# Create desktop shortcut
echo -e "${YELLOW}Creating desktop shortcut...${NC}"
ssh "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "cat > /home/deck/Desktop/DeckImagePicker.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Deck Image Picker
Comment=Image selection tool for Steam Deck
Exec=${REMOTE_APP_DIR}/image_picker
Icon=image-x-generic
Path=${REMOTE_APP_DIR}
Terminal=false
Categories=Graphics;Utility;
EOF"

ssh "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "chmod +x /home/deck/Desktop/DeckImagePicker.desktop"
echo -e "${GREEN}✓ Desktop shortcut created${NC}"
echo ""

# Display completion message
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo "The application has been installed to: ${REMOTE_APP_DIR}"
echo ""
echo "To run the application on Steam Deck:"
echo "  Option 1: Double-click 'Deck Image Picker' icon on Desktop"
echo "  Option 2: Open Konsole and run: ${REMOTE_APP_DIR}/image_picker"
echo "  Option 3: Navigate to ~/Applications/${APP_NAME} and run image_picker"
echo ""
echo "Keyboard shortcuts:"
echo "  P / Right Arrow - Pick/mark image"
echo "  X / Left Arrow  - Reject image"
echo "  C               - Clear selection"
echo "  Arrow keys      - Navigate images"
echo ""
echo -e "${YELLOW}Optional: Add to Steam Library${NC}"
echo "  1. Open Steam in Desktop Mode"
echo "  2. Games → Add a Non-Steam Game"
echo "  3. Browse to ${REMOTE_APP_DIR}/image_picker"
echo "  4. Configure controller input mapping for keyboard shortcuts"
echo ""
