#!/bin/bash

#================================================================
#	项目: masscan 一键脚本
#	版本: 1.0
#	作者: Gemini
#	时间: 2024-05-28
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

# masscan的源码目录
MASSCAN_DIR="/opt/masscan"

# 1. 安装masscan
install_masscan() {
    echo -e "${YELLOW}正在更新软件包列表...${RESET}"
    apt update -y
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：软件包列表更新失败。${RESET}"
        exit 1
    fi

    echo -e "${YELLOW}正在安装依赖项 (git, gcc, make, libpcap-dev)...${RESET}"
    apt install -y git gcc make libpcap-dev
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：依赖项安装失败。${RESET}"
        exit 1
    fi

    if [ -d "$MASSCAN_DIR" ]; then
        echo -e "${YELLOW}检测到旧的 masscan 源码目录，正在删除...${RESET}"
        rm -rf "$MASSCAN_DIR"
    fi

    echo -e "${YELLOW}正在从 GitHub 下载 masscan 源码...${RESET}"
    git clone https://github.com/robertdavidgraham/masscan.git "$MASSCAN_DIR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：从 GitHub 下载源码失败。${RESET}"
        exit 1
    fi

    cd "$MASSCAN_DIR"

    echo -e "${YELLOW}正在编译 masscan...${RESET}"
    make
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：编译失败。${RESET}"
        exit 1
    fi

    echo -e "${YELLOW}正在安装 masscan...${RESET}"
    make install
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误：安装失败。${RESET}"
        exit 1
    fi

    # 清理编译文件
    make clean

    # 验证安装
    if command -v masscan &> /dev/null; then
        echo -e "${GREEN}masscan 安装成功！版本信息如下：${RESET}"
        masscan --version
    else
        echo -e "${RED}错误：masscan 安装失败，找不到 masscan 命令。${RESET}"
    fi

    cd /root # 返回主目录
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 2. 执行扫描
execute_scan() {
    # 每次执行扫描前，建议进入一个工作目录
    # 这里我们统一在 /root 目录下执行，并将日志和结果文件也放在这里
    cd /root || exit

    echo -e "${YELLOW}请输入要扫描的 IP 段（多个 IP 段请用空格隔开）:${RESET}"
    read -r ip_ranges

    if [ -z "$ip_ranges" ]; then
        echo -e "${RED}错误：IP 段不能为空。${RESET}"
        return
    fi

    echo -e "${YELLOW}请输入保存结果的 XML 文件名 (例如: results.xml):${RESET}"
    read -r filename

    if [ -z "$filename" ]; then
        echo -e "${RED}错误：文件名不能为空。${RESET}"
        return
    fi

    # 检查之前的 nohup.out 文件
    if [ -f "nohup.out" ]; then
        echo -e "${YELLOW}检测到旧的 nohup.out 日志文件。建议在开始新任务前删除它（菜单选项 4）。${RESET}"
    fi

    echo -e "${GREEN}正在后台启动 masscan 扫描...${RESET}"
    echo -e "扫描命令: nohup masscan $ip_ranges -p0-65535 -oX $filename --rate 1000 &"
    nohup masscan $ip_ranges -p0-65535 -oX "$filename" --rate 1000 &

    # 检查进程是否成功启动
    if pgrep -f "masscan $ip_ranges" > /dev/null; then
        echo -e "${GREEN}扫描任务已成功启动！PID: $(pgrep -f "masscan $ip_ranges")${RESET}"
        echo -e "${YELLOW}您可以使用菜单选项 '3' 查看实时扫描进程。${RESET}"
    else
        echo -e "${RED}错误：扫描任务启动失败，请检查参数或 masscan 是否正确安装。${RESET}"
    fi

    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 3. 查看扫描进程
view_scan_process() {
    cd /root || exit
    if [ -f "nohup.out" ]; then
        echo -e "${YELLOW}--- 实时扫描日志 (按 Ctrl+C 退出查看) ---${RESET}"
        tail -f nohup.out
    else
        echo -e "${RED}未找到 nohup.out 日志文件。可能没有正在进行的扫描任务，或者您不在正确的目录下。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 4. 删除 nohup.out 文件
delete_log_file() {
    cd /root || exit
    if [ -f "nohup.out" ]; then
        rm -f nohup.out
        echo -e "${GREEN}nohup.out 日志文件已成功删除。${RESET}"
    else
        echo -e "${RED}未找到 nohup.out 日志文件，无需删除。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 5. 卸载 masscan
uninstall_masscan() {
    echo -e "${YELLOW}正在卸载 masscan...${RESET}"
    if [ -d "$MASSCAN_DIR" ]; then
        cd "$MASSCAN_DIR"
        make uninstall
        if [ $? -eq 0 ]; then
             echo -e "${GREEN}masscan 已通过 'make uninstall' 成功卸载。${RESET}"
        else
            echo -e "${RED}'make uninstall' 执行失败，可能是因为 Makefile 不支持。将尝试手动删除。${RESET}"
        fi
        cd /root # 返回主目录
        echo -e "${YELLOW}正在删除 masscan 源码目录...${RESET}"
        rm -rf "$MASSCAN_DIR"
    else
        echo -e "${YELLOW}未找到 masscan 源码目录。${RESET}"
    fi

    # 尝试删除可执行文件，以防 'make uninstall' 失败或不可用
    if command -v masscan &> /dev/null; then
        echo -e "${YELLOW}正在删除 masscan 可执行文件...${RESET}"
        rm -f "$(command -v masscan)"
    fi


    if ! command -v masscan &> /dev/null; then
        echo -e "${GREEN}masscan 卸载完成！${RESET}"
    else
        echo -e "${RED}卸载可能未完全成功，仍然可以找到 masscan 命令。${RESET}"
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
        1)
            install_masscan
            ;;
        2)
            execute_scan
            ;;
        3)
            view_scan_process
            ;;
        4)
            delete_log_file
            ;;
        5)
            uninstall_masscan
            ;;
        6)
            echo -e "${GREEN}感谢使用，正在退出...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请输入 1 到 6 之间的数字。${RESET}"
            sleep 2
            ;;
    esac
done