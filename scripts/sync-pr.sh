#!/bin/bash
# sync-pr.sh
# 同步 PR 分支最新代码

set -e

# 参数
REMOTE="${1:-origin}"
BRANCH="$2"
STRATEGY="${3:-merge}"  # merge 或 rebase

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Sync PR Branch: $BRANCH${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

# 检查当前分支
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo -e "${YELLOW}当前分支 ($CURRENT_BRANCH) 与目标分支 ($BRANCH) 不匹配${NC}"
    echo -e "${YELLOW}是否切换分支？(y/n)${NC}"
    read -r confirm
    if [ "$confirm" = "y" ]; then
        git checkout "$BRANCH"
    else
        echo -e "${RED}中止操作${NC}"
        exit 1
    fi
fi

# 检查是否有未提交更改
UNCOMMITTED=$(git status --porcelain)
if [ -n "$UNCOMMITTED" ]; then
    echo -e "${YELLOW}有未提交的更改:${NC}"
    echo "$UNCOMMITTED"
    echo -e "${YELLOW}处理方式？${NC}"
    echo "  1) stash (推荐)"
    echo "  2) commit"
    echo "  3) 中止"
    read -r choice
    
    case $choice in
        1)
            git stash push -m "auto-stash before sync"
            AUTO_STASH=true
            ;;
        2)
            echo "输入 commit 信息:"
            read -r msg
            git commit -am "$msg"
            ;;
        3)
            echo -e "${RED}中止操作${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            exit 1
            ;;
    esac
fi

# Fetch 最新代码
echo -e "${BLUE}[1/3] Fetching latest from $REMOTE/$BRANCH...${NC}"
git fetch "$REMOTE" "$BRANCH"

# 检查是否有新提交
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse "$REMOTE/$BRANCH")

if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo -e "${GREEN}已经是最新，无需同步${NC}"
    exit 0
fi

echo -e "${BLUE}Local:  $LOCAL_COMMIT${NC}"
echo -e "${BLUE}Remote: $REMOTE_COMMIT${NC}"

# 同步策略
case $STRATEGY in
    merge)
        echo -e "${BLUE}[2/3] Merging $REMOTE/$BRANCH...${NC}"
        if ! git merge "$REMOTE/$BRANCH" --no-edit 2>&1; then
            echo -e "${RED}合并冲突！需要手动解决${NC}"
            echo -e "${YELLOW}解决后运行：git merge --continue${NC}"
            exit 1
        fi
        ;;
    rebase)
        echo -e "${BLUE}[2/3] Rebasing onto $REMOTE/$BRANCH...${NC}"
        if ! git rebase "$REMOTE/$BRANCH" 2>&1; then
            echo -e "${RED}Rebase 冲突！需要手动解决${NC}"
            echo -e "${YELLOW}解决后运行：git rebase --continue${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}未知策略：$STRATEGY (使用 merge 或 rebase)${NC}"
        exit 1
        ;;
esac

# 恢复 stash (如果有)
if [ "$AUTO_STASH" = true ]; then
    echo -e "${BLUE}[3/3] Restoring stashed changes...${NC}"
    if ! git stash pop 2>&1; then
        echo -e "${YELLOW}Stash 恢复时有冲突，请手动解决${NC}"
    fi
fi

# 完成
echo -e "${GREEN}✓ 同步完成${NC}"
echo ""
echo -e "${BLUE}当前状态:${NC}"
git status --short

# 显示新增的 commits
NEW_COMMITS=$(git rev-list "$REMOTE_COMMIT"..HEAD --oneline)
if [ -n "$NEW_COMMITS" ]; then
    echo ""
    echo -e "${BLUE}新增 commits:${NC}"
    echo "$NEW_COMMITS"
fi
