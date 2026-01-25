#!/bin/bash

# =============================================================================
# SOMMELIER - Project Setup Script
# =============================================================================
# Usage: ./setup.sh
# =============================================================================

set -e

echo "🍷 Sommelier Project Setup"
echo "=========================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1 found"
        return 0
    else
        echo -e "  ${RED}✗${NC} $1 not found"
        return 1
    fi
}

MISSING=0
check_command "node" || MISSING=1
check_command "npm" || MISSING=1
check_command "firebase" || MISSING=1

if [ $MISSING -eq 1 ]; then
    echo ""
    echo -e "${RED}Missing prerequisites. Please install:${NC}"
    echo "  - Node.js 20+: https://nodejs.org/"
    echo "  - Firebase CLI: npm install -g firebase-tools"
    exit 1
fi

echo ""
echo "📦 Installing Cloud Functions dependencies..."
cd firebase/functions
npm install
cd ../..

echo ""
echo "🔧 Setting up environment..."
if [ ! -f "firebase/functions/.env" ]; then
    cp firebase/functions/.env.example firebase/functions/.env
    echo -e "${YELLOW}⚠${NC}  Created .env file - please add your ANTHROPIC_API_KEY"
else
    echo -e "${GREEN}✓${NC} .env file already exists"
fi

echo ""
echo "🔥 Firebase Setup"
echo "=================="
echo ""
echo "Next steps:"
echo ""
echo "1. Login to Firebase:"
echo "   ${YELLOW}firebase login${NC}"
echo ""
echo "2. Create/select a Firebase project:"
echo "   ${YELLOW}firebase use --add${NC}"
echo ""
echo "3. Enable required services in Firebase Console:"
echo "   - Authentication (Email, Apple Sign-In)"
echo "   - Firestore Database"
echo "   - Storage"
echo "   - Functions"
echo ""
echo "4. Enable Google Cloud APIs:"
echo "   - Cloud Vision API"
echo ""
echo "5. Add your Anthropic API key to firebase/functions/.env:"
echo "   ${YELLOW}ANTHROPIC_API_KEY=sk-ant-...${NC}"
echo ""
echo "6. Deploy Firebase resources:"
echo "   ${YELLOW}cd firebase && firebase deploy${NC}"
echo ""
echo "7. iOS Setup:"
echo "   - Open ios/Sommelier.xcodeproj in Xcode"
echo "   - Download GoogleService-Info.plist from Firebase Console"
echo "   - Add to Xcode project"
echo "   - Build and run"
echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
