#!/bin/bash
# install.sh - PR Comment Fix Skill 安装脚本
# 支持：Claude Code, Cursor, VSCode, OpenCode

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SKILL_NAME="pr-comment-fix"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  PR Comment Fix Skill - Installer                     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检测平台
detect_platform() {
    if [ -d "$HOME/.claude" ]; then
        echo "claude-code"
    elif [ -d "$HOME/.cursor" ]; then
        echo "cursor"
    elif [ -d "$HOME/.vscode" ]; then
        echo "vscode"
    elif command -v opencode &> /dev/null; then
        echo "opencode"
    else
        echo "unknown"
    fi
}

# 安装到 Claude Code
install_claude_code() {
    local target_dir="$HOME/.claude/skills/$SKILL_NAME"
    
    echo -e "${BLUE}Installing to Claude Code...${NC}"
    
    # 创建目录
    mkdir -p "$target_dir"
    
    # 复制文件
    cp -r "$SKILL_DIR/SKILL.md" "$target_dir/"
    cp -r "$SKILL_DIR/agents/" "$target_dir/" 2>/dev/null || true
    cp -r "$SKILL_DIR/scripts/" "$target_dir/" 2>/dev/null || true
    cp -r "$SKILL_DIR/references/" "$target_dir/" 2>/dev/null || true
    cp -r "$SKILL_DIR/lib/" "$target_dir/" 2>/dev/null || true
    cp -r "$SKILL_DIR/ecc-adapter/" "$target_dir/" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Installed to: $target_dir${NC}"
    echo ""
    echo -e "${YELLOW}Usage in Claude Code:${NC}"
    echo "  /skill load pr-comment-fix"
    echo "  Or ask: 'Help me fix PR comments'"
}

# 安装到 Cursor
install_cursor() {
    local target_dir="$HOME/.cursor/skills/$SKILL_NAME"
    
    echo -e "${BLUE}Installing to Cursor...${NC}"
    
    mkdir -p "$target_dir"
    cp -r "$SKILL_DIR/SKILL.md" "$target_dir/"
    
    echo -e "${GREEN}✓ Installed to: $target_dir${NC}"
    echo ""
    echo -e "${YELLOW}Usage in Cursor:${NC}"
    echo "  Add @pr-comment-fix in chat"
    echo "  Or install as plugin from marketplace"
}

# 安装到 VSCode (GitHub Copilot)
install_vscode() {
    local target_dir="$HOME/.vscode/copilot/skills/$SKILL_NAME"
    
    echo -e "${BLUE}Installing to VSCode (Copilot)...${NC}"
    
    mkdir -p "$target_dir"
    cp -r "$SKILL_DIR/SKILL.md" "$target_dir/"
    
    echo -e "${GREEN}✓ Installed to: $target_dir${NC}"
    echo ""
    echo -e "${YELLOW}Usage in VSCode:${NC}"
    echo "  Use in Copilot chat: @pr-comment-fix"
}

# 安装到 OpenCode
install_opencode() {
    local target_dir="$HOME/.opencode/skills/$SKILL_NAME"
    
    echo -e "${BLUE}Installing to OpenCode...${NC}"
    
    mkdir -p "$target_dir"
    cp -r "$SKILL_DIR/SKILL.md" "$target_dir/"
    cp -r "$SKILL_DIR/agents/" "$target_dir/" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Installed to: $target_dir${NC}"
    echo ""
    echo -e "${YELLOW}Usage in OpenCode:${NC}"
    echo "  /skill load pr-comment-fix"
}

# 创建项目级安装（当前项目）
install_local() {
    local target_dir="./.claude/skills/$SKILL_NAME"
    
    echo -e "${BLUE}Installing to local project...${NC}"
    
    mkdir -p "$target_dir"
    cp -r "$SKILL_DIR/SKILL.md" "$target_dir/"
    cp -r "$SKILL_DIR/agents/" "$target_dir/" 2>/dev/null || true
    cp -r "$SKILL_DIR/scripts/" "$target_dir/" 2>/dev/null || true
    cp -r "$SKILL_DIR/references/" "$target_dir/" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Installed to: $target_dir${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  Skill will auto-load for this project"
}

# 主菜单
main() {
    echo "Select installation target:"
    echo ""
    echo "  1) Claude Code (global)"
    echo "  2) Cursor (global)"
    echo "  3) VSCode Copilot (global)"
    echo "  4) OpenCode (global)"
    echo "  5) Local project (./.claude/skills/)"
    echo "  6) All supported platforms"
    echo "  7) Uninstall"
    echo ""
    
    if [ -z "$1" ]; then
        echo -n "Enter choice [1-7]: "
        read -r choice
    else
        choice="$1"
    fi
    
    case $choice in
        1)
            install_claude_code
            ;;
        2)
            install_cursor
            ;;
        3)
            install_vscode
            ;;
        4)
            install_opencode
            ;;
        5)
            install_local
            ;;
        6)
            install_claude_code
            install_cursor
            install_vscode
            install_opencode
            echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║  All platforms installed successfully!              ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
            ;;
        7)
            echo -e "${YELLOW}Uninstalling...${NC}"
            rm -rf "$HOME/.claude/skills/$SKILL_NAME"
            rm -rf "$HOME/.cursor/skills/$SKILL_NAME"
            rm -rf "$HOME/.vscode/copilot/skills/$SKILL_NAME"
            rm -rf "$HOME/.opencode/skills/$SKILL_NAME"
            rm -rf "./.claude/skills/$SKILL_NAME"
            echo -e "${GREEN}✓ Uninstalled from all platforms${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
}

# 自动检测并安装
auto_install() {
    local platform
    platform=$(detect_platform)
    
    echo -e "${BLUE}Auto-detected platform: $platform${NC}"
    echo ""
    
    case $platform in
        claude-code)
            install_claude_code
            ;;
        cursor)
            install_cursor
            ;;
        vscode)
            install_vscode
            ;;
        opencode)
            install_opencode
            ;;
        *)
            echo -e "${YELLOW}No supported platform detected.${NC}"
            echo "Installing to local project..."
            install_local
            ;;
    esac
}

# 命令行参数
if [ "$1" == "--auto" ]; then
    auto_install
elif [ "$1" == "--claude" ]; then
    install_claude_code
elif [ "$1" == "--cursor" ]; then
    install_cursor
elif [ "$1" == "--vscode" ]; then
    install_vscode
elif [ "$1" == "--opencode" ]; then
    install_opencode
elif [ "$1" == "--local" ]; then
    install_local
elif [ "$1" == "--all" ]; then
    main 6
elif [ "$1" == "--uninstall" ]; then
    main 7
else
    main
fi
