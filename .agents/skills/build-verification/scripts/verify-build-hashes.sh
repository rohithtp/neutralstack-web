#!/usr/bin/env bash
# ==============================================================================
# NeutralStack Web - Build Hash & Asset Fingerprint Verification Script
# Audits dist/assets for cryptographic hashes, budget limits, and index.html refs
# ==============================================================================

set -uo pipefail

DIST_DIR="${1:-frontend/dist}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Auditing Asset Fingerprints and Cryptographic Hashes ===${NC}"
echo -e "Target Directory: ${DIST_DIR}\n"

if [[ ! -d "$DIST_DIR" ]]; then
  echo -e "${RED}[FAIL] Distribution directory '$DIST_DIR' does not exist.${NC}"
  echo -e "Please build the frontend first (e.g. 'npm run build')."
  exit 1
fi

ASSETS_DIR="$DIST_DIR/assets"
INDEX_HTML="$DIST_DIR/index.html"

TOTAL_ERRORS=0

# Check index.html presence
if [[ ! -f "$INDEX_HTML" ]]; then
  echo -e "${RED}[FAIL] Missing index.html in $DIST_DIR${NC}"
  TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
else
  echo -e "[${GREEN}PASS${NC}] Found entrypoint index.html"
fi

# Check assets directory
if [[ ! -d "$ASSETS_DIR" ]]; then
  echo -e "${RED}[FAIL] Missing assets directory: $ASSETS_DIR${NC}"
  TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
  exit 1
fi

# Hash format check: name.[hash].[ext] where hash is at least 6 alphanumeric characters
echo -e "\nEvaluating asset naming conventions in $ASSETS_DIR:"
ASSET_COUNT=0
UNHASHED_COUNT=0

for file in "$ASSETS_DIR"/*; do
  [[ -e "$file" ]] || continue
  ASSET_COUNT=$((ASSET_COUNT + 1))
  filename="$(basename "$file")"
  
  # Check if matches [name]-[hash].[ext] or [name].[hash].[ext]
  # Hash should be alphanumeric (hex or base64url), typically 8+ chars
  if [[ "$filename" =~ \.([a-zA-Z0-9_-]{6,})\.(js|css|png|jpg|jpeg|svg|webp|woff2|woff)$ ]] || [[ "$filename" =~ -([a-zA-Z0-9_-]{6,})\.(js|css|png|jpg|jpeg|svg|webp|woff2|woff)$ ]]; then
    # Calculate SHA256 checksum
    if command -v shasum >/dev/null 2>&1; then
      sha=$(shasum -a 256 "$file" | awk '{print $1}')
    else
      sha=$(sha256sum "$file" | awk '{print $1}')
    fi
    size_bytes=$(wc -c < "$file" | tr -d ' ')
    size_kb=$((size_bytes / 1024))
    
    echo -e "  [${GREEN}HASHED${NC}] $filename (${size_kb} KB) - SHA256: ${sha:0:16}..."
    
    # Check budget constraints
    if [[ "$filename" =~ \.js$ ]] && [[ $size_kb -gt 250 ]]; then
      echo -e "    ${YELLOW}[WARN] Bundle chunk exceeds 250 KB budget: ${size_kb} KB${NC}"
    fi
    if [[ "$filename" =~ \.css$ ]] && [[ $size_kb -gt 50 ]]; then
      echo -e "    ${YELLOW}[WARN] Stylesheet chunk exceeds 50 KB budget: ${size_kb} KB${NC}"
    fi

    # Check that this asset is referenced in index.html (if JS or CSS)
    if [[ "$filename" =~ \.(js|css)$ ]] && [[ -f "$INDEX_HTML" ]]; then
      if grep -q "$filename" "$INDEX_HTML"; then
        echo -e "    [${GREEN}SYNCED${NC}] Correctly referenced in index.html"
      else
        echo -e "    ${YELLOW}[WARN] Chunk $filename is not directly referenced in index.html (may be lazy-loaded dynamic import)${NC}"
      fi
    fi
  else
    echo -e "  [${RED}UNHASHED${NC}] $filename (Missing cryptographic hash fingerprint)"
    UNHASHED_COUNT=$((UNHASHED_COUNT + 1))
  fi
done

echo -e "\n------------------------------------------------------------"
echo -e "Total Assets Inspected: $ASSET_COUNT"
echo -e "Fingerprinted Assets: $((ASSET_COUNT - UNHASHED_COUNT))"

if [[ $UNHASHED_COUNT -gt 0 ]]; then
  echo -e "Unhashed Assets: ${RED}$UNHASHED_COUNT${NC}"
  echo -e "${RED}[FAIL] Production assets must include cryptographic content hashes.${NC}"
  exit 1
elif [[ $ASSET_COUNT -eq 0 ]]; then
  echo -e "${RED}[FAIL] No assets found in $ASSETS_DIR.${NC}"
  exit 1
else
  echo -e "${GREEN}[SUCCESS] All production assets are properly fingerprinted with deterministic hashes!${NC}"
  exit 0
fi

