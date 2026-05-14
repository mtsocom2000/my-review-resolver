#!/bin/bash
# check-branch.sh
# Check if local branch matches PR branch

set -e

# Arguments
PR_URL="$1"
REMOTE="${2:-origin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse PR URL
parse_pr_url() {
    local url="$1"
    
    # GitHub URL: https://github.com/owner/repo/pull/123
    # or: github.com/owner/repo/pull/123
    if [[ "$url" =~ github\.com[/:]([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        PR_OWNER="${BASH_REMATCH[1]}"
        PR_REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        echo "parsed:owner=$PR_OWNER,repo=$PR_REPO,pr=$PR_NUMBER"
        return 0
    fi
    
    # GitLab URL: https://gitlab.com/owner/repo/-/merge_requests/123
    if [[ "$url" =~ gitlab\.com[/:]([^/]+)/([^/]+)/-/merge_requests/([0-9]+) ]]; then
        PR_OWNER="${BASH_REMATCH[1]}"
        PR_REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        echo "parsed:owner=$PR_OWNER,repo=$PR_REPO,pr=$PR_NUMBER"
        return 0
    fi
    
    echo -e "${RED}Could not parse PR URL: $url${NC}" >&2
    return 1
}

# Get PR branch info
get_pr_branch() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    # Try gh CLI (GitHub)
    if command -v gh &> /dev/null; then
        local pr_info
        pr_info=$(gh api repos/"$owner"/"$repo"/pulls/"$pr_number" 2>/dev/null) || true
        
        if [ -n "$pr_info" ]; then
            PR_BRANCH=$(echo "$pr_info" | jq -r '.head.ref')
            PR_REMOTE=$(echo "$pr_info" | jq -r '.head.repo.clone_url')
            echo "branch=$PR_BRANCH,remote=$PR_REMOTE"
            return 0
        fi
    fi
    
    # Try glab CLI (GitLab)
    if command -v glab &> /dev/null; then
        local mr_info
        mr_info=$(glab api projects/"$owner"/"$repo"/merge_requests/"$pr_number" 2>/dev/null) || true
        
        if [ -n "$mr_info" ]; then
            PR_BRANCH=$(echo "$mr_info" | jq -r '.source_branch')
            PR_REMOTE=$(echo "$mr_info" | jq -r '.web_url')
            echo "branch=$PR_BRANCH,remote=$PR_REMOTE"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}Cannot fetch PR branch info, please specify manually${NC}" >&2
    return 1
}

# Check local branch status
check_local_branch() {
    local expected_branch="$1"
    
    CURRENT_BRANCH=$(git branch --show-current)
    
    UNCOMMITTED=$(git status --porcelain)
    
    UPSTREAM=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo "")
    
    echo "current_branch=$CURRENT_BRANCH"
    echo "expected_branch=$expected_branch"
    echo "upstream=$UPSTREAM"
    echo "uncommitted=$( [ -n "$UNCOMMITTED" ] && echo "true" || echo "false" )"
    
    if [ "$CURRENT_BRANCH" != "$expected_branch" ]; then
        echo "match=false"
        echo "reason=branch_mismatch"
        return 1
    fi
    
    if [ -n "$UNCOMMITTED" ]; then
        echo "match=false"
        echo "reason=uncommitted_changes"
        return 1
    fi
    
    echo "match=true"
    return 0
}

# Main function
main() {
    if [ -z "$PR_URL" ]; then
        echo -e "${RED}Usage: $0 <PR_URL> [remote]${NC}" >&2
        exit 1
    fi
    
    parse_result=$(parse_pr_url "$PR_URL")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    echo "$parse_result"
    
    branch_result=$(get_pr_branch "$PR_OWNER" "$PR_REPO" "$PR_NUMBER")
    if [ $? -eq 0 ]; then
        echo "$branch_result"
        
        PR_BRANCH=$(echo "$branch_result" | grep -o 'branch=[^,]*' | cut -d= -f2)
        
        check_result=$(check_local_branch "$PR_BRANCH")
        echo "$check_result"
    else
        echo -e "${YELLOW}Please enter the PR source branch name manually:${NC}"
        read -r PR_BRANCH
        check_result=$(check_local_branch "$PR_BRANCH")
        echo "$check_result"
    fi
}

main
