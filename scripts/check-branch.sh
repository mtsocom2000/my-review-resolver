#!/bin/bash
# check-branch.sh
# 检查本地分支是否与 PR 分支匹配

set -e

# 参数
PR_URL="$1"
REMOTE="${2:-origin}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 解析 PR URL
parse_pr_url() {
    local url="$1"
    
    # GitHub URL 格式: https://github.com/owner/repo/pull/123
    # 或: github.com/owner/repo/pull/123
    if [[ "$url" =~ github\.com[/:]([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        PR_OWNER="${BASH_REMATCH[1]}"
        PR_REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        echo "parsed:owner=$PR_OWNER,repo=$PR_REPO,pr=$PR_NUMBER"
        return 0
    fi
    
    # GitLab URL 格式: https://gitlab.com/owner/repo/-/merge_requests/123
    if [[ "$url" =~ gitlab\.com[/:]([^/]+)/([^/]+)/-/merge_requests/([0-9]+) ]]; then
        PR_OWNER="${BASH_REMATCH[1]}"
        PR_REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        echo "parsed:owner=$PR_OWNER,repo=$PR_REPO,pr=$PR_NUMBER"
        return 0
    fi
    
    echo -e "${RED}无法解析 PR URL: $url${NC}" >&2
    return 1
}

# 获取 PR 分支信息
get_pr_branch() {
    local owner="$1"
    local repo="$2"
    local pr_number="$3"
    
    # 尝试使用 gh CLI (GitHub)
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
    
    # 尝试使用 glab CLI (GitLab)
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
    
    echo -e "${YELLOW}无法获取 PR 分支信息，需要手动指定${NC}" >&2
    return 1
}

# 检查本地分支状态
check_local_branch() {
    local expected_branch="$1"
    
    # 当前分支
    CURRENT_BRANCH=$(git branch --show-current)
    
    # 检查是否有未提交更改
    UNCOMMITTED=$(git status --porcelain)
    
    # 当前分支的 upstream
    UPSTREAM=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo "")
    
    echo "current_branch=$CURRENT_BRANCH"
    echo "expected_branch=$expected_branch"
    echo "upstream=$UPSTREAM"
    echo "uncommitted=$( [ -n "$UNCOMMITTED" ] && echo "true" || echo "false" )"
    
    # 判断是否匹配
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

# 主函数
main() {
    if [ -z "$PR_URL" ]; then
        echo -e "${RED}用法：$0 <PR_URL> [remote]${NC}" >&2
        exit 1
    fi
    
    # 解析 PR URL
    parse_result=$(parse_pr_url "$PR_URL")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    echo "$parse_result"
    
    # 获取 PR 分支
    branch_result=$(get_pr_branch "$PR_OWNER" "$PR_REPO" "$PR_NUMBER")
    if [ $? -eq 0 ]; then
        echo "$branch_result"
        
        # 提取分支名
        PR_BRANCH=$(echo "$branch_result" | grep -o 'branch=[^,]*' | cut -d= -f2)
        
        # 检查本地分支
        check_result=$(check_local_branch "$PR_BRANCH")
        echo "$check_result"
    else
        echo -e "${YELLOW}请手动输入 PR 源分支名称：${NC}"
        read -r PR_BRANCH
        check_result=$(check_local_branch "$PR_BRANCH")
        echo "$check_result"
    fi
}

main
