#!/bin/bash
# post-resolution.sh
# 回复 PR 评论标记为 resolved

set -e

# 参数
PR_URL="$1"
COMMENT_IDS="$2"  # 逗号分隔的评论 ID 列表
MESSAGE="$3"      # 可选的回复消息

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 解析 PR URL
parse_pr_url() {
    local url="$1"
    
    if [[ "$url" =~ github\.com[/:]([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
        PR_OWNER="${BASH_REMATCH[1]}"
        PR_REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        PLATFORM="github"
        return 0
    fi
    
    if [[ "$url" =~ gitlab\.com[/:]([^/]+)/([^/]+)/-/merge_requests/([0-9]+) ]]; then
        PR_OWNER="${BASH_REMATCH[1]}"
        PR_REPO="${BASH_REMATCH[2]}"
        PR_NUMBER="${BASH_REMATCH[3]}"
        PLATFORM="gitlab"
        return 0
    fi
    
    echo -e "${RED}无法解析 PR URL${NC}" >&2
    return 1
}

# GitHub: 回复评论
github_reply() {
    local comment_id="$1"
    local message="$2"
    
    echo -e "${BLUE}Replying to GitHub comment #$comment_id...${NC}"
    
    gh api \
        repos/"$PR_OWNER"/"$PR_REPO"/pulls/"$PR_NUMBER"/comments/"$comment_id"/replies \
        -X POST \
        -f body="$message"
    
    echo -e "${GREEN}✓ Replied to #$comment_id${NC}"
}

# GitHub: 在 PR 中统一回复
github_summary() {
    local resolved_ids="$1"
    local message="$2"
    
    echo -e "${BLUE}Posting summary comment...${NC}"
    
    gh api \
        repos/"$PR_OWNER"/"$PR_REPO"/issues/"$PR_NUMBER"/comments \
        -X POST \
        -f body="$message"
    
    echo -e "${GREEN}✓ Summary posted${NC}"
}

# GitLab: 解决评论
gitlab_resolve() {
    local comment_id="$1"
    local project_id
    
    # 获取 project ID
    project_id=$(glab api projects/"$PR_OWNER"/"$PR_REPO" --jq '.id')
    
    echo -e "${BLUE}Resolving GitLab note #$comment_id...${NC}"
    
    curl --request POST \
        --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "https://gitlab.com/api/v4/projects/$project_id/merge_requests/$PR_NUMBER/notes/$comment_id/resolve"
    
    echo -e "${GREEN}✓ Resolved #$comment_id${NC}"
}

# 主函数
main() {
    if [ -z "$PR_URL" ]; then
        echo -e "${RED}用法：$0 <PR_URL> <comment_ids> [message]${NC}" >&2
        echo "  comment_ids: 逗号分隔的评论 ID，或 'all' 表示所有"
        echo "  message: 可选的回复消息"
        exit 1
    fi
    
    # 解析 URL
    if ! parse_pr_url "$PR_URL"; then
        exit 1
    fi
    
    echo -e "${BLUE}Platform: $PLATFORM${NC}"
    echo -e "${BLUE}Repo: $PR_OWNER/$PR_REPO${NC}"
    echo -e "${BLUE}PR: #$PR_NUMBER${NC}"
    echo ""
    
    # 默认消息
    if [ -z "$MESSAGE" ]; then
        MESSAGE="✓ Resolved in latest commit"
    fi
    
    case $PLATFORM in
        github)
            # 检查 gh CLI
            if ! command -v gh &> /dev/null; then
                echo -e "${RED}需要安装 GitHub CLI (gh)${NC}"
                echo "https://cli.github.com/"
                exit 1
            fi
            
            # 处理评论 ID
            if [ "$COMMENT_IDS" = "all" ]; then
                echo -e "${YELLOW}获取所有评论...${NC}"
                # TODO: 获取所有未解决的评论
                echo -e "${YELLOW}'all' 选项尚未实现，请指定评论 ID${NC}"
                exit 1
            else
                # 逐个回复
                IFS=',' read -ra IDS <<< "$COMMENT_IDS"
                for id in "${IDS[@]}"; do
                    github_reply "$id" "$MESSAGE"
                done
            fi
            
            # 可选：发布总结
            echo ""
            echo -e "${YELLOW}是否发布总结评论？(y/n)${NC}"
            read -r post_summary
            if [ "$post_summary" = "y" ]; then
                resolved_list=""
                IFS=',' read -ra IDS <<< "$COMMENT_IDS"
                for id in "${IDS[@]}"; do
                    resolved_list+="- Comment #$id: Resolved\n"
                done
                
                summary="## PR Comment Fix - Resolved\n\n已修复以下问题:\n\n$resolved_list\n修复已推送到最新 commit."
                github_summary "$COMMENT_IDS" "$summary"
            fi
            ;;
            
        gitlab)
            # 检查 glab CLI
            if ! command -v glab &> /dev/null; then
                echo -e "${RED}需要安装 GitLab CLI (glab)${NC}"
                exit 1
            fi
            
            # 检查 token
            if [ -z "$GITLAB_TOKEN" ]; then
                echo -e "${RED}请设置 GITLAB_TOKEN 环境变量${NC}"
                exit 1
            fi
            
            # 解决评论
            IFS=',' read -ra IDS <<< "$COMMENT_IDS"
            for id in "${IDS[@]}"; do
                gitlab_resolve "$id"
            done
            ;;
            
        *)
            echo -e "${RED}不支持的平台：$PLATFORM${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ All comments resolved${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
}

main
