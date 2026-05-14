#!/bin/bash
# post-resolution.sh (legacy)
# Post reply to PR comments and mark as resolved
# Superseded by reply-to-comment.sh — kept for backward compatibility

set -e

# Arguments
PR_URL="$1"
COMMENT_IDS="$2"  # Comma-separated list of comment IDs, or "all"
MESSAGE="$3"      # Optional reply message

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <PR_URL> <comment_ids> [message]"
    echo "  comment_ids: Comma-separated comment IDs, or 'all' for all"
    echo "  message: Optional reply message"
    exit 1
}

# Parse PR URL
parse_url() {
    local url="$1"
    
    if [[ "$url" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        NUMBER="${BASH_REMATCH[3]}"
        PLATFORM="github"
    elif [[ "$url" =~ gitlab\..+/([^/]+)/([^/]+)/-/merge_requests/([0-9]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        NUMBER="${BASH_REMATCH[3]}"
        PLATFORM="gitlab"
    else
        echo -e "${RED}Could not parse PR URL${NC}" >&2
        exit 1
    fi
}

# GitHub: Reply to a comment
github_reply_comment() {
    local comment_id="$1"
    local message="$2"
    
    gh api "repos/$OWNER/$REPO/pulls/$NUMBER/comments/$comment_id/replies" \
        -X POST \
        -f "body=$message" --silent && \
    echo -e "${GREEN}Replied to comment $comment_id${NC}"
}

# GitHub: Resolve PR Review Comment (inline comments)
github_resolve_review_comment() {
    local comment_id="$1"
    local message="$2"
    
    if [ -n "$message" ]; then
        gh api "repos/$OWNER/$REPO/pulls/comments/$comment_id" \
            -X PATCH \
            -f "body=$message" --silent && \
        echo -e "${GREEN}Updated comment $comment_id${NC}"
    else
        gh api "repos/$OWNER/$REPO/pulls/comments/$comment_id/reactions" \
            -X POST \
            -f "content=+1" --silent && \
        echo -e "${GREEN}Resolved comment $comment_id${NC}"
    fi
}

# GitHub: Post a general reply on the PR
github_reply_general() {
    local message="$1"
    
    gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments" \
        -X POST \
        -f "body=$message" --silent && \
    echo -e "${GREEN}Posted general reply${NC}"
}

# Main function
main() {
    if [ -z "$PR_URL" ] || [ -z "$COMMENT_IDS" ]; then
        usage
    fi
    
    parse_url "$PR_URL"
    
    # Default message
    if [ -z "$MESSAGE" ]; then
        MESSAGE="Addressed in latest commit."
    fi
    
    if [ "$PLATFORM" = "github" ]; then
        # Check gh CLI
        if ! command -v gh &> /dev/null; then
            echo -e "${RED}GitHub CLI (gh) is required for this operation${NC}" >&2
            echo "Install: https://cli.github.com/" >&2
            exit 1
        fi
        
        # Process comments
        if [ "$COMMENT_IDS" = "all" ]; then
            echo -e "${YELLOW}Posting reply on PR...${NC}"
            github_reply_general "$MESSAGE"
        else
            IFS=',' read -ra IDS <<< "$COMMENT_IDS"
            for id in "${IDS[@]}"; do
                id=$(echo "$id" | xargs)  # Trim whitespace
                echo -e "${YELLOW}Processing comment $id...${NC}"
                github_reply_comment "$id" "$MESSAGE"
            done
        fi
        
        echo -e "${GREEN}Done${NC}"
    elif [ "$PLATFORM" = "gitlab" ]; then
        # GitLab: resolve comments
        if ! command -v glab &> /dev/null; then
            echo -e "${RED}GitLab CLI (glab) is required for GitLab operations${NC}" >&2
            exit 1
        fi
        
        # Get project ID
        PROJECT_ID=$(echo "$OWNER/$REPO" | sed 's/\//%2F/g')
        
        if [ "$COMMENT_IDS" = "all" ]; then
            echo -e "${YELLOW}Posting note on MR...${NC}"
            glab api "projects/$PROJECT_ID/merge_requests/$NUMBER/notes" \
                -X POST \
                -f "body=$MESSAGE" --silent && \
            echo -e "${GREEN}Posted note${NC}"
        else
            IFS=',' read -ra IDS <<< "$COMMENT_IDS"
            for id in "${IDS[@]}"; do
                id=$(echo "$id" | xargs)
                echo -e "${YELLOW}Replying to note $id...${NC}"
                glab api "projects/$PROJECT_ID/merge_requests/$NUMBER/notes/$id" \
                    -X POST \
                    -f "body=$MESSAGE" --silent && \
                echo -e "${GREEN}Replied to note $id${NC}"
            done
        fi
        
        echo -e "${GREEN}Done${NC}"
    fi
}

main
