#!/bin/bash

#================================================================
#	项目: masscan 一键脚本 (通用版)
#	版本: 3.1 (强化卸载功能，修正逻辑)
#	作者: AiLi1337
#================================================================

# 定义颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 变量
PKG_MANAGER=""
INSTALL_CMD=""
DEPS=""

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误：该脚本必须以 root 权限运行，请使用 'sudo' 或切换到 'root' 用户后重试。${RESET}" 1>&2
   exit 1
fi

# --- 系统检测和包管理器设置 ---
if command -v apt-get &> /dev/null; then
    echo -e "${GREEN}检测到 Debian/Ubuntu 系统。${RESET}"
    PKG_MANAGER="apt-get"
    INSTALL_CMD="apt-get install -y"
    DEPS="git gcc make libpcap-dev"
elif command -v yum &> /dev/null; then
    echo -e "${GREEN}检测到 CentOS/RHEL 系统。${RESET}"
    PKG_MANAGER="yum"
    INSTALL_CMD="yum install -y"
    DEPS="git gcc make libpcap-devel" # 注意这里的依赖名是 libpcap-devel
else
    echo -e "${RED}错误：无法确定您的操作系统包管理器。该脚本仅支持使用 apt 或 yum 的系统。${RESET}"
    exit 1
fi

# masscan的工作和源码目录
MASSCAN_DIR="/opt/masscan"

# 确保masscan目录存在
mkdir -p "$MASSCAN_DIR"

# 1. 安装masscan
install_masscan() {
    echo -e "${YELLOW}正在更新软件包缓存...${RESET}"
    # CentOS使用 'yum makecache fast'
    if [ "$PKG_MANAGER" == "yum" ]; then
        yum makecache fast &>/dev/null
    else
        $PKG_MANAGER update -y &>/dev/null
    fi

    echo -e "${YELLOW}正在安装依赖项: $DEPS...${RESET}"
    $INSTALL_CMD $DEPS
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：依赖项安装失败。${RESET}"
        exit 1
    fi

    if [ -d "$MASSCAN_DIR/masscan" ]; then
        echo -e "${YELLOW}检测到旧的 masscan 源码，正在删除...${RESET}"
        rm -rf "$MASSCAN_DIR/masscan"
    fi

    echo -e "${YELLOW}正在从 GitHub 下载 masscan 源码...${RESET}"
    git clone https://github.com/robertdavidgraham/masscan.git "$MASSCAN_DIR/masscan"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：从 GitHub 下载源码失败。${RESET}"
        exit 1
    fi

    cd "$MASSCAN_DIR/masscan"

    echo -e "${YELLOW}正在编译并安装 masscan...${RESET}"
    make -s && make -s install
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：编译或安装失败。${RESET}"
        exit 1
    fi

    make clean

    if command -v masscan &> /dev/null; then
        echo -e "${GREEN}✅ masscan 安装成功！${RESET}"
    else
        echo -e "${RED}❌ 错误：masscan 安装失败。${RESET}"
    fi

    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 2. 执行扫描
execute_scan() {
    cd "$MASSCAN_DIR" || exit

    echo -e "${YELLOW}请输入要扫描的 IP 段 (多个 IP 段请用空格隔开):${RESET}"
    read -r ip_ranges

    if [ -z "$ip_ranges" ]; then
        echo -e "${RED}错误：IP 段不能为空。${RESET}"
        return
    fi

    echo -e "${YELLOW}请输入保存结果的文件名 (必须以 .xml 结尾):${RESET}"
    read -r filename

    if [[ ! "$filename" == *.xml ]]; then
        echo -e "${RED}错误：文件名必须以 .xml 结尾。${RESET}"
        echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
        read -r
        return
    fi

    if [ -f "$MASSCAN_DIR/nohup.out" ]; then
        echo -e "${YELLOW}检测到旧的 nohup.out 日志文件。建议在开始新任务前删除它 (菜单选项 4)。${RESET}"
    fi

    echo -e "${GREEN}🚀 正在后台启动 masscan 扫描...${RESET}"
    echo -e "日志文件: $MASSCAN_DIR/nohup.out"
    echo -e "结果文件: $MASSCAN_DIR/$filename"
    nohup masscan $ip_ranges -p0-65535 -oX "$filename" --rate 1000 &

    if pgrep -f "masscan $ip_ranges" > /dev/null; then
        echo -e "${GREEN}扫描任务已成功启动！PID: $(pgrep -f "masscan $ip_ranges")${RESET}"
        echo -e "${YELLOW}您可以使用菜单选项 '3' 查看实时扫描进程。${RESET}"
    else
        echo -e "${RED}❌ 错误：扫描任务启动失败。${RESET}"
    fi

    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 3. 查看扫描进程
view_scan_process() {
    if [ -f "$MASSCAN_DIR/nohup.out" ]; then
        echo -e "${YELLOW}--- 实时扫描日志 (按 Ctrl+C 停止查看) ---${RESET}"
        tail -f "$MASSCAN_DIR/nohup.out"
    else
        echo -e "${RED}未找到 nohup.out 日志文件。可能没有正在进行的扫描任务。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 4. 删除 nohup.out 文件
delete_log_file() {
    if [ -f "$MASSCAN_DIR/nohup.out" ]; then
        rm -f "$MASSCAN_DIR/nohup.out"
        echo -e "${GREEN}✅ nohup.out 日志文件已成功删除。${RESET}"
    else
        echo -e "${RED}未找到 nohup.out 日志文件，无需删除。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 5. 卸载 masscan (v3.1 新逻辑)
uninstall_masscan() {
    echo -e "${YELLOW}正在卸载 masscan...${RESET}"

    # 步骤 1: 如果源码目录存在，尝试 'make uninstall'
    if [ -d "$MASSCAN_DIR/masscan" ]; then
        echo -e "${YELLOW}发现源码目录，正在尝试 'make uninstall'...${RESET}"
        cd "$MASSCAN_DIR/masscan"
        make uninstall &>/dev/null
        cd /root
    else
        echo -e "${YELLOW}未找到源码目录，将进行强制删除。${RESET}"
    fi

    # 步骤 2: 强制删除 masscan 可执行文件
    if command -v masscan &> /dev/null; then
        echo -e "${YELLOW}正在删除 masscan 可执行文件: $(command -v masscan)...${RESET}"
        rm -f "$(command -v masscan)"
    fi

    # 步骤 3: 删除整个工作目录
    if [ -d "$MASSCAN_DIR" ]; then
        echo -e "${YELLOW}正在删除工作目录: $MASSCAN_DIR...${RESET}"
        rm -rf "$MASSCAN_DIR"
    fi

    # 步骤 4: 最终验证
    if ! command -v masscan &> /dev/null; then
        echo -e "\n${GREEN}✅ masscan 已成功卸载！${RESET}"
    else
        echo -e "\n${RED}❌ 卸载失败，请手动检查。可能原因：权限不足或文件被占用。${RESET}"
    fi

    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}


# 主菜单
show_menu() {
    clear
    echo -e "================================================="
    echo -e "            ${GREEN}masscan 一键脚本 (v3.1)${RESET}            "
    echo -e "================================================="
    echo -e " 工作目录: ${YELLOW}${MASSCAN_DIR}${RESET}"
    echo -e "-------------------------------------------------"
    echo -e " ${YELLOW}1.${RESET} 安装 masscan"
    echo -e " ${YELLOW}2.${RESET} 执行扫描"
    echo -e " ${YELLOW}3.${RESET} 查看扫描进程"
    echo -e " ${YELLOW}4.${RESET} 删除 nohup.out 日志文件"
    echo -e " ${YELLOW}5.${RESET} 卸载 masscan"
    echo -e " ${YELLOW}6.${RESET} 退出脚本"
    echo -e "================================================="
    echo -n "请输入选项 [1-6]: "
    read -r choice
}

# 主循环
while true; do
    # 在显示菜单前，先检测masscan是否已安装，以决定菜单项的可用性
    # (此部分为未来可优化的功能，暂不实现)
    show_menu
    case $choice in
        1) install_masscan ;;
        2) execute_scan ;;
        3) view_scan_process ;;
        4) delete_log_file ;;
        5) uninstall_masscan ;;
        6) echo -e "${GREEN}👋 感谢使用，正在退出...${RESET}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请输入 1 到 6 之间的数字。${RESET}"; sleep 2 ;;
    esac
done