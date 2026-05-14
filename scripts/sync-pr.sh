#!/bin/bash
# sync-pr.sh
# Sync latest changes from remote for PR branch

set -e

# Arguments
REMOTE="$1"
BRANCH="$2"
STRATEGY="${3:-merge}"  # merge or rebase

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$REMOTE" ] || [ -z "$BRANCH" ]; then
    echo -e "${RED}Usage: $0 <remote> <branch> [strategy]${NC}" >&2
    echo "  strategy: merge (default) or rebase" >&2
    exit 1
fi

echo "remote=$REMOTE"
echo "branch=$BRANCH"

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo -e "${YELLOW}Current branch ($CURRENT_BRANCH) does not match target ($BRANCH)${NC}"
    echo -e "${YELLOW}Switch branches? (y/n)${NC}"
    read -r SWITCH
    if [ "$SWITCH" = "y" ] || [ "$SWITCH" = "Y" ]; then
        git checkout "$BRANCH"
    else
        echo -e "${RED}Aborting${NC}"
        exit 1
    fi
fi

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain)
if [ -n "$UNCOMMITTED" ]; then
    echo -e "${YELLOW}Uncommitted changes found:${NC}"
    echo "$UNCOMMITTED"
    echo -e "${YELLOW}How to proceed?${NC}"
    echo "  1) stash (recommended)"
    echo "  2) commit"
    echo "  3) abort"
    read -r HANDLE_UNCOMMITTED
    
    case $HANDLE_UNCOMMITTED in
        1)
            git stash push -m "Auto-stash before PR sync"
            echo "Changes stashed"
            STASHED=true
            ;;
        2)
            echo "Enter commit message:"
            read -r COMMIT_MSG
            git add -A
            git commit -m "$COMMIT_MSG"
            ;;
        *)
            echo -e "${RED}Aborting${NC}"
            exit 1
            ;;
    esac
fi

# Fetch and sync
echo -e "${CYAN}Fetching from $REMOTE/$BRANCH...${NC}"
git fetch "$REMOTE" "$BRANCH"

if [ "$STRATEGY" = "rebase" ]; then
    echo -e "${CYAN}Rebasing onto $REMOTE/$BRANCH...${NC}"
    git rebase "$REMOTE/$BRANCH"
else
    echo -e "${CYAN}Merging $REMOTE/$BRANCH...${NC}"
    git merge "$REMOTE/$BRANCH" --no-edit
fi

# Restore stash if needed
if [ "${STASHED:-false}" = "true" ]; then
    git stash pop
    echo "Stash restored"
fi

# Show status
echo -e "${GREEN}Sync complete${NC}"
git log --oneline -5

exit 0
