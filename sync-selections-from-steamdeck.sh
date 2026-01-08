#!/bin/bash
# Sync .deck-selections.json files FROM Steam Deck back to main computer
# Usage: ./sync-selections-from-steamdeck.sh <steam-deck-ip> <destination-folder>

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Arguments
STEAM_DECK_IP="$1"
DESTINATION_FOLDER="$2"

# Configuration
STEAM_DECK_USER="deck"
REVIEWS_BASE_DIR="/home/deck/Pictures/Reviews"

# Validation
if [ -z "$STEAM_DECK_IP" ] || [ -z "$DESTINATION_FOLDER" ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo "Usage: $0 <steam-deck-ip> <destination-folder>"
    echo ""
    echo "Example:"
    echo "  $0 192.168.1.100 ~/Documents/image-selections"
    echo ""
    echo "This will download all .deck-selections.json files with folder structure preserved"
    exit 1
fi

# Create destination folder
mkdir -p "$DESTINATION_FOLDER"
echo -e "${GREEN}✓ Destination folder ready: $DESTINATION_FOLDER${NC}"

# Test SSH connection
echo -e "${YELLOW}Testing connection to Steam Deck...${NC}"
if ! ssh -o ConnectTimeout=5 "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "echo 'OK'" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to Steam Deck at ${STEAM_DECK_IP}${NC}"
    echo ""
    echo "Make sure SSH is enabled and the IP address is correct"
    exit 1
fi
echo -e "${GREEN}✓ Connected to Steam Deck${NC}"

# Check if Reviews directory exists on Steam Deck
echo -e "${YELLOW}Checking for Reviews directory on Steam Deck...${NC}"
if ! ssh "${STEAM_DECK_USER}@${STEAM_DECK_IP}" "[ -d ${REVIEWS_BASE_DIR} ]"; then
    echo -e "${RED}Error: Reviews directory not found on Steam Deck${NC}"
    echo "Expected: ${REVIEWS_BASE_DIR}"
    echo ""
    echo "The directory may not have been created yet."
    echo "Try syncing images first with sync-images-to-steamdeck.sh"
    exit 1
fi
echo -e "${GREEN}✓ Reviews directory found${NC}"

# Count selection files on Steam Deck
echo -e "${YELLOW}Scanning for selection files...${NC}"
SELECTION_COUNT=$(ssh "${STEAM_DECK_USER}@${STEAM_DECK_IP}" \
    "find ${REVIEWS_BASE_DIR} -type f -name '.deck-selections.json' 2>/dev/null | wc -l")

if [ "$SELECTION_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No selection files found on Steam Deck${NC}"
    echo ""
    echo "This could mean:"
    echo "  - You haven't reviewed any images yet"
    echo "  - No picks or rejects have been made (only marked images are saved)"
    echo ""
    echo "To create selection files:"
    echo "  1. Launch Deck Image Picker on Steam Deck"
    echo "  2. Select a folder with images"
    echo "  3. Mark some images as Pick (P) or Reject (X)"
    echo "  4. Selections are auto-saved"
    exit 0
fi

echo -e "${GREEN}Found $SELECTION_COUNT selection file(s)${NC}"
echo ""

# Sync with folder structure preservation
echo -e "${YELLOW}Downloading selection files...${NC}"
rsync -avz --progress \
    --relative \
    --include='*/' \
    --include='.deck-selections.json' \
    --exclude='*' \
    "${STEAM_DECK_USER}@${STEAM_DECK_IP}:${REVIEWS_BASE_DIR}/./" \
    "${DESTINATION_FOLDER}/"

echo ""
echo -e "${GREEN}=== Download Complete! ===${NC}"
echo "Selection files saved to:"
echo "  ${DESTINATION_FOLDER}"
echo ""
echo "Folder structure has been preserved."
echo ""

# Show summary of selections
echo -e "${YELLOW}Selection Summary:${NC}"
echo "---"

# Find all selection files and show pick/reject counts
find "$DESTINATION_FOLDER" -name '.deck-selections.json' | while read -r file; do
    # Get the folder name (parent directory)
    folder=$(dirname "$file" | xargs basename)

    # Count picks and rejects
    picks=$(grep -o '"pick"' "$file" 2>/dev/null | wc -l)
    rejects=$(grep -o '"reject"' "$file" 2>/dev/null | wc -l)

    echo "Folder: $folder"
    echo "  Picks:   $picks"
    echo "  Rejects: $rejects"
    echo "---"
done

echo ""
echo "You can now review the selection files or process the picked images."
echo ""
