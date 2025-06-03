#!/bin/bash

#================================================================
#	项目: masscan 一键脚本
#	版本: 2.0
#	作者: AiLi
#	时间: 2025-06-03
#================================================================

# 定义颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误：该脚本必须以 root 权限运行，请使用 'sudo' 或切换到 'root' 用户后重试。${RESET}" 1>&2
   exit 1
fi

# masscan的源码和工作目录
MASSCAN_DIR="/opt/masscan"

# 确保masscan目录存在
mkdir -p "$MASSCAN_DIR"

# 1. 安装masscan
install_masscan() {
    echo -e "${YELLOW}正在更新软件包列表...${RESET}"
    apt update -y &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：软件包列表更新失败。${RESET}"
        exit 1
    fi

    echo -e "${YELLOW}正在安装依赖项 (git, gcc, make, libpcap-dev)...${RESET}"
    apt install -y git gcc make libpcap-dev &>/dev/null
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

    # 检查之前的 nohup.out 文件
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
    if [ -f "$MASSCAN_DIR/nohup.out" ]; {
        rm -f "$MASSCAN_DIR/nohup.out"
        echo -e "${GREEN}✅ nohup.out 日志文件已成功删除。${RESET}"
    } else {
        echo -e "${RED}未找到 nohup.out 日志文件，无需删除。${RESET}"
    }
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 5. 卸载 masscan
uninstall_masscan() {
    echo -e "${YELLOW}正在卸载 masscan...${RESET}"
    if [ -d "$MASSCAN_DIR/masscan" ]; then
        cd "$MASSCAN_DIR/masscan"
        make uninstall &>/dev/null
        cd /root
        rm -rf "$MASSCAN_DIR"
        echo -e "${GREEN}✅ masscan 源码目录已删除。${RESET}"
    else
        echo -e "${YELLOW}未找到 masscan 源码目录。${RESET}"
    fi

    if ! command -v masscan &> /dev/null; then
        echo -e "${GREEN}masscan 卸载完成！${RESET}"
    else
        echo -e "${RED}❌ 卸载失败，请手动检查。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}


# 主菜单
show_menu() {
    clear
    echo -e "================================================="
    echo -e "            ${GREEN}masscan 一键脚本${RESET}            "
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