#!/bin/bash
# Sync images from main computer TO Steam Deck for review
# Usage: ./sync-images-to-steamdeck.sh <steam-deck-ip> <source-folder> <session-name>

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Arguments
STEAM_DECK_IP="$1"
SOURCE_FOLDER="$2"
SESSION_NAME="$3"

# Configuration
STEAM_DECK_USER="deck"
REVIEWS_BASE_DIR="/home/deck/Pictures/Reviews"
DESTINATION_DIR="${REVIEWS_BASE_DIR}/${SESSION_NAME}"

# Validation
if [ -z "$STEAM_DECK_IP" ] || [ -z "$SOURCE_FOLDER" ] || [ -z "$SESSION_NAME" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo "Usage: $0 <steam-deck-ip> <source-folder> <session-name>"
    echo ""
    echo "Example:"
    echo "  $0 192.168.1.100 ~/Pictures/vacation-2024 vacation-2024-batch1"
    echo ""
    echo "This will create: /home/deck/Pictures/Reviews/vacation-2024-batch1/"
    exit 1
fi

# Verify source folder exists
if [ ! -d "$SOURCE_FOLDER" ]; then
    echo -e "${RED}Error: Source folder not found: $SOURCE_FOLDER${NC}"
    exit 1
fi

# Count images in source folder
echo -e "${YELLOW}Counting images in source folder...${NC}"
IMAGE_COUNT=$(find "$SOURCE_FOLDER" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) 2>/dev/null | wc -l)
echo -e "${GREEN}Found $IMAGE_COUNT images in source folder${NC}"

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}Warning: No images found in source folder${NC}"
    echo "Supported formats: jpg, jpeg, png, gif, bmp, webp"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Test SSH connection
echo -e "${YELLOW}Testing connection to Steam Deck...${NC}"
if ! ssh -o ConnectTimeout=5 "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "echo 'OK'" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to Steam Deck at ${STEAM_DECK_IP}${NC}"
    echo ""
    echo "Make sure you have:"
    echo "  1. Set a password on Steam Deck: passwd"
    echo "  2. Enabled SSH: sudo systemctl enable sshd && sudo systemctl start sshd"
    echo "  3. Correct IP address"
    echo ""
    echo "To find your Steam Deck IP:"
    echo "  1. Open Konsole on Steam Deck (Desktop Mode)"
    echo "  2. Run: ip addr | grep 'inet '"
    echo "  3. Look for an IP like 192.168.x.x"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Steam Deck${NC}"

# Create destination directory structure
echo -e "${YELLOW}Creating destination directory on Steam Deck...${NC}"
ssh "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "mkdir -p ${DESTINATION_DIR}"
echo -e "${GREEN}✓ Directory created: ${DESTINATION_DIR}${NC}"
echo ""

# Sync images
echo -e "${YELLOW}Syncing images (this may take a while)...${NC}"
rsync -avz --progress \
    --include='*.jpg' --include='*.jpeg' --include='*.png' \
    --include='*.gif' --include='*.bmp' --include='*.webp' \
    --include='*.JPG' --include='*.JPEG' --include='*.PNG' \
    --include='*.GIF' --include='*.BMP' --include='*.WEBP' \
    --exclude='*' \
    "${SOURCE_FOLDER}/" \
    "${STEAM_DECK_USER}@${STEAM_DECK_IP}:${DESTINATION_DIR}/"

echo ""
echo -e "${GREEN}=== Sync Complete! ===${NC}"
echo "Images are now available on Steam Deck at:"
echo "  ${DESTINATION_DIR}"
echo ""
echo "To review images:"
echo "  1. Launch Deck Image Picker on Steam Deck"
echo "  2. Select '${SESSION_NAME}' folder from the list"
echo "  3. Start reviewing images using:"
echo "     - P or Right Arrow: Pick/mark image"
echo "     - X or Left Arrow: Reject image"
echo "     - C: Clear selection"
echo ""
echo "When finished, sync selections back with:"
echo "  ./sync-selections-from-steamdeck.sh ${STEAM_DECK_IP} <destination-folder>"
echo ""
