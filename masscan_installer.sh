#!/bin/bash

#================================================================
#	项目: masscan 一键脚本 (通用版)
#	版本: 3.3 (增加删除指定XML文件功能)
#	作者: AiLi1337
#================================================================

# 定义颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"
CYAN="\033[36m"

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
    PKG_MANAGER="apt-get"
    INSTALL_CMD="apt-get install -y"
    DEPS="git gcc make libpcap-dev"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    INSTALL_CMD="yum install -y"
    DEPS="git gcc make libpcap-devel"
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
    echo -e "${YELLOW}正在检测系统并更新软件包缓存...${RESET}"
    if [ "$PKG_MANAGER" == "yum" ]; then
        yum makecache fast &>/dev/null
    else
        $PKG_MANAGER update -y &>/dev/null
    fi

    echo -e "${YELLOW}正在安装依赖项: $DEPS...${RESET}"
    $INSTALL_CMD $DEPS &>/dev/null
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
    
    if [ -f "nohup.out" ]; then
        echo -e "${YELLOW}发现旧的 nohup.out 日志文件，已自动删除。${RESET}"
        rm -f "nohup.out"
    fi

    echo -e "${YELLOW}请输入要扫描的 IP 段 (多个 IP 段请用空格隔开):${RESET}"
    read -r ip_ranges

    if [ -z "$ip_ranges" ]; then
        echo -e "${RED}错误：IP 段不能为空。${RESET}"
        return
    fi

    echo -e "${YELLOW}请输入保存结果的文件名 (无需.xml后缀):${RESET}"
    read -r filename_base

    if [ -z "$filename_base" ]; then
        echo -e "${RED}错误：文件名不能为空。${RESET}"
        return
    fi
    
    filename="${filename_base}.xml"

    echo -e "${GREEN}🚀 正在后台启动 masscan 扫描...${RESET}"
    echo -e "日志文件: ${CYAN}$MASSCAN_DIR/nohup.out${RESET}"
    echo -e "结果文件: ${CYAN}$MASSCAN_DIR/$filename${RESET}"
    nohup masscan $ip_ranges -p0-65535 -oX "$filename" --rate 1000 &

    if pgrep -f "masscan $ip_ranges" > /dev/null; then
        echo -e "${GREEN}扫描任务已成功启动！PID: $(pgrep -f "masscan $ip_ranges")${RESET}"
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
        echo -e "${RED}未找到 nohup.out 日志文件。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 4. 查看已有的XML文件
list_xml_files() {
    echo -e "${YELLOW}--- 当前已有的扫描结果文件 ---${RESET}"
    if ls -1 "$MASSCAN_DIR"/*.xml 1>/dev/null 2>&1; then
        ls -lht "$MASSCAN_DIR"/*.xml | awk '{print "    " NR ". " $9 "  (" $5 ")  " $6 " " $7 " " $8}' | sed "s|$MASSCAN_DIR/||"
    else
        echo -e "${RED}    当前没有找到任何 .xml 结果文件。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 5. 删除指定的XML文件 (新功能)
delete_xml_file() {
    cd "$MASSCAN_DIR" || exit
    
    # 将找到的xml文件名存入数组
    xml_files=($(ls -1 *.xml 2>/dev/null))

    if [ ${#xml_files[@]} -eq 0 ]; then
        echo -e "${RED}没有找到任何 .xml 文件可供删除。${RESET}"
        echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
        read -r
        return
    fi

    echo -e "${YELLOW}--- 请选择要删除的 .xml 文件 ---${RESET}"
    # 循环输出带编号的文件列表
    for i in "${!xml_files[@]}"; do
        echo -e "    ${CYAN}$(($i + 1))${RESET}. ${xml_files[$i]}"
    done
    echo -e "    ${CYAN}0${RESET}. 取消操作"
    
    echo -n "请输入数字 [0-$((${#xml_files[@]}))]: "
    read -r choice

    # 验证输入是否为数字
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo -e "\n${RED}错误：请输入一个有效的数字。${RESET}"
        sleep 2
        return
    fi
    
    # 处理取消操作
    if [ "$choice" -eq 0 ]; then
        echo -e "\n${YELLOW}操作已取消。${RESET}"
        sleep 1
        return
    fi
    
    # 验证输入是否在有效范围内
    if [ "$choice" -gt 0 ] && [ "$choice" -le ${#xml_files[@]} ]; then
        # 从数组中获取文件名（数组索引从0开始，所以需要减1）
        target_file=${xml_files[$(($choice - 1))]}
        
        echo -en "\n${RED}您确定要永久删除文件 ${CYAN}'$target_file'${RED} 吗？(y/N): ${RESET}"
        read -r confirm
        
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            rm -f "$target_file"
            echo -e "\n${GREEN}✅ 文件 '$target_file' 已成功删除。${RESET}"
        else
            echo -e "\n${YELLOW}删除操作已取消。${RESET}"
        fi
    else
        echo -e "\n${RED}错误：无效的选项 '$choice'。${RESET}"
    fi
    
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}


# 6. 手动删除 nohup.out 文件
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

# 7. 卸载 masscan
uninstall_masscan() {
    echo -e "${YELLOW}正在卸载 masscan...${RESET}"
    # ... (卸载逻辑保持不变)
    if [ -d "$MASSCAN_DIR/masscan" ]; then
        echo -e "${YELLOW}发现源码目录，正在尝试 'make uninstall'...${RESET}"
        cd "$MASSCAN_DIR/masscan"
        make uninstall &>/dev/null
        cd /root
    else
        echo -e "${YELLOW}未找到源码目录，将进行强制删除。${RESET}"
    fi
    if command -v masscan &> /dev/null; then
        echo -e "${YELLOW}正在删除 masscan 可执行文件: $(command -v masscan)...${RESET}"
        rm -f "$(command -v masscan)"
    fi
    if [ -d "$MASSCAN_DIR" ]; then
        echo -e "${YELLOW}正在删除工作目录: $MASSCAN_DIR...${RESET}"
        rm -rf "$MASSCAN_DIR"
    fi
    if ! command -v masscan &> /dev/null; then
        echo -e "\n${GREEN}✅ masscan 已成功卸载！${RESET}"
    else
        echo -e "\n${RED}❌ 卸载失败，请手动检查。${RESET}"
    fi
    echo -e "\n${GREEN}按 Enter 键返回主菜单...${RESET}"
    read -r
}

# 主菜单
show_menu() {
    clear
    echo -e "================================================="
    echo -e "            ${GREEN}masscan 一键脚本 (v3.3)${RESET}            "
    echo -e "================================================="
    echo -e " 工作目录: ${CYAN}${MASSCAN_DIR}${RESET}"
    echo -e "-------------------------------------------------"
    echo -e " ${YELLOW}1.${RESET} 安装 masscan"
    echo -e " ${YELLOW}2.${RESET} 执行扫描 (自动清理旧日志)"
    echo -e " ${YELLOW}3.${RESET} 查看扫描进程"
    echo -e " ${YELLOW}4.${RESET} 查看扫描结果 (.xml 文件)"
    echo -e " ${CYAN}5. 删除指定 .xml 文件${RESET}         ${GREEN}<- 新功能${RESET}"
    echo -e " ${YELLOW}6.${RESET} 手动删除 nohup.out 日志"
    echo -e " ${YELLOW}7.${RESET} 卸载 masscan"
    echo -e " ${YELLOW}8.${RESET} 退出脚本"
    echo -e "================================================="
    echo -n "请输入选项 [1-8]: "
    read -r choice
}

# 主循环
while true; do
    show_menu
    case $choice in
        1) install_masscan ;;
        2) execute_scan ;;
        3) view_scan_process ;;
        4) list_xml_files ;;
        5) delete_xml_file ;; # 新功能
        6) delete_log_file ;;
        7) uninstall_masscan ;;
        8) echo -e "${GREEN}👋 感谢使用，正在退出...${RESET}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请输入 1 到 8 之间的数字。${RESET}"; sleep 2 ;;
    esac
done