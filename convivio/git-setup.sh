#!/bin/bash

# =============================================================================
# SOMMELIER - Git Repository Setup
# =============================================================================
# Run this after extracting the zip to initialize Git and push to GitHub
# =============================================================================

set -e

echo "🍷 Sommelier - Git Setup"
echo "========================"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git not found. Please install Git first."
    exit 1
fi

# Check if gh CLI is installed (optional, for creating repo)
HAS_GH=false
if command -v gh &> /dev/null; then
    HAS_GH=true
    echo "✓ GitHub CLI found - can create repo automatically"
else
    echo "⚠ GitHub CLI not found - you'll need to create the repo manually"
fi

echo ""

# Initialize git if not already
if [ ! -d ".git" ]; then
    echo "📦 Initializing Git repository..."
    git init
    echo "✓ Git initialized"
else
    echo "✓ Git already initialized"
fi

# Create initial commit
echo ""
echo "📝 Creating initial commit..."
git add .
git commit -m "🍷 Initial commit: Sommelier wine cellar app

MVP structure including:
- Firebase Cloud Functions (TypeScript)
  - /api/extract: OCR + LLM wine label extraction
  - /api/propose: AI dinner menu & wine pairing
  - /api/chat: Conversational sommelier with tool calling
- iOS App (SwiftUI)
  - Cellar inventory management
  - Wine scanning with Vision API
  - AI chat interface
  - Dinner planning
  - Friend management with food preferences
- Firestore security rules with RBAC
- Complete data model and TypeScript types

Tech stack: Firebase, Cloud Functions, SwiftUI, Claude API, Vision API"

echo "✓ Initial commit created"

# Create repo and push if gh is available
if [ "$HAS_GH" = true ]; then
    echo ""
    read -p "🚀 Create GitHub repository and push? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Repository name (default: sommelier): " REPO_NAME
        REPO_NAME=${REPO_NAME:-sommelier}
        
        read -p "Private repository? (y/n) " -n 1 -r PRIVATE
        echo ""
        
        VISIBILITY="--public"
        if [[ $PRIVATE =~ ^[Yy]$ ]]; then
            VISIBILITY="--private"
        fi
        
        echo "Creating repository..."
        gh repo create "$REPO_NAME" $VISIBILITY --source=. --push
        
        echo ""
        echo "✓ Repository created and pushed!"
        echo "  https://github.com/$(gh api user -q .login)/$REPO_NAME"
    fi
else
    echo ""
    echo "📋 Next steps to push to GitHub:"
    echo ""
    echo "1. Create a new repository on GitHub:"
    echo "   https://github.com/new"
    echo ""
    echo "2. Add remote and push:"
    echo "   git remote add origin https://github.com/YOUR_USERNAME/sommelier.git"
    echo "   git branch -M main"
    echo "   git push -u origin main"
fi

echo ""
echo "✓ Done!"
