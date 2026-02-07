#!/bin/bash

# ============================================================================
# 配置区
# ============================================================================
GITHUB_URL="https://raw.githubusercontent.com/DavidMartineg/OpenList-Proxy-Installer/main/openlist-proxy_Linux_x86_64.tar.gz"
WORK_DIR="/root/openlist-proxy"
BINARY_NAME="openlist-proxy"
ARCHIVE_NAME="openlist-proxy_Linux_x86_64.tar.gz"

# ============================================================================
# 函数定义
# ============================================================================

download_and_extract() {
    echo "1. 下载二进制文件..."
    
    if command -v curl &> /dev/null; then
        curl -L -o "$ARCHIVE_NAME" "$GITHUB_URL"
    elif command -v wget &> /dev/null; then
        wget -O "$ARCHIVE_NAME" "$GITHUB_URL"
    else
        echo "错误: 需要 curl 或 wget"
        exit 1
    fi
    
    if [[ ! -f "$ARCHIVE_NAME" ]]; then
        echo "错误: 下载失败"
        exit 1
    fi
    
    echo "2. 解压文件..."
    tar -xzvf "$ARCHIVE_NAME" "$BINARY_NAME" 2>/dev/null
    
    if [[ ! -f "$BINARY_NAME" ]]; then
        echo "错误: 解压失败或文件不存在"
        exit 1
    fi
    
    rm -f "$ARCHIVE_NAME"
    chmod +x "./$BINARY_NAME"
}

collect_parameters() {
    echo "3. 配置参数..."
    
    # 必须参数：地址
    while true; do
        read -p "请输入网盘地址 (必须): " address
        if [[ -n "$address" ]]; then
            break
        fi
        echo "错误: 地址不能为空"
    done
    
    # 必须参数：token
    while true; do
        read -p "请输入token (必须): " token
        if [[ -n "$token" ]]; then
            break
        fi
        echo "错误: token不能为空"
    done
    
    # 可选参数：端口
    read -p "请输入监听端口 (默认: 5243): " user_port
    port="${user_port:-5243}"
    
    # 可选参数：HTTPS
    read -p "是否启用HTTPS? (y/N): " use_https
    if [[ "$use_https" == "y" || "$use_https" == "Y" ]]; then
        https_enabled="true"
        echo "4. 配置SSL证书..."
        setup_ssl_certs
    else
        https_enabled="false"
        echo "4. 跳过SSL证书配置（HTTP模式）"
    fi
}

setup_ssl_certs() {
    # 证书文件
    if [[ -f "$HOME/server.crt" ]]; then
        echo "找到 ~/server.crt"
        read -p "是否使用此文件? (Y/n): " confirm
        if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
            cp "$HOME/server.crt" "./server.crt"
            echo "已复制证书到工作目录"
        else
            get_cert_path
        fi
    else
        echo "未找到 ~/server.crt"
        get_cert_path
    fi
    
    # 密钥文件
    if [[ -f "$HOME/server.key" ]]; then
        echo "找到 ~/server.key"
        read -p "是否使用此文件? (Y/n): " confirm
        if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
            cp "$HOME/server.key" "./server.key"
            chmod 600 "./server.key"
            echo "已复制密钥到工作目录"
        else
            get_key_path
        fi
    else
        echo "未找到 ~/server.key"
        get_key_path
    fi
}

get_cert_path() {
    while true; do
        read -p "请输入证书文件路径: " cert_path
        if [[ -f "$cert_path" ]]; then
            cp "$cert_path" "./server.crt"
            echo "已复制证书到工作目录"
            break
        else
            echo "文件不存在: $cert_path"
        fi
    done
}

get_key_path() {
    while true; do
        read -p "请输入密钥文件路径: " key_path
        if [[ -f "$key_path" ]]; then
            cp "$key_path" "./server.key"
            chmod 600 "./server.key"
            echo "已复制密钥到工作目录"
            break
        else
            echo "文件不存在: $key_path"
        fi
    done
}

build_command() {
    local args=()
    
    args+=("-address")
    args+=("$address")
    
    if [[ "$https_enabled" == "true" ]]; then
        args+=("-cert")
        args+=("./server.crt")
        args+=("-https")
        args+=("true")
        args+=("-key")
        args+=("./server.key")
    fi
    
    # 只在端口不是默认值5243时才添加-port参数
    if [[ "$port" != "5243" ]]; then
        args+=("-port")
        args+=("$port")
    fi
    
    args+=("-token")
    args+=("$token")
    
    echo "${args[@]}"
}

run_service() {
    echo "5. 启动服务..."
    echo ""
    
    ./"$BINARY_NAME" $cmd_args
}

# ============================================================================
# 主程序
# ============================================================================
main() {
    echo "开始安装网盘代理服务"
    echo "========================================"
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR" || {
        echo "错误: 无法进入工作目录 $WORK_DIR"
        exit 1
    }
    
    echo "工作目录: $WORK_DIR"
    echo ""
    
    download_and_extract
    echo ""
    
    collect_parameters
    echo ""
    
    # 显示配置摘要
    echo "配置摘要:"
    echo "  网盘地址: $address"
    echo "  Token: ${token:0:4}******"
    echo "  端口: $port"
    echo "  HTTPS: $([ "$https_enabled" == "true" ] && echo "启用" || echo "禁用")"
    if [[ "$https_enabled" == "true" ]]; then
        echo "  证书: $WORK_DIR/server.crt"
        echo "  密钥: $WORK_DIR/server.key"
    fi
    echo ""

    # 显示将要执行的命令（在确认之前）
    echo ""
    echo "将要执行的命令:"
    cmd_args=$(build_command)
    echo "./$BINARY_NAME $cmd_args"
    echo ""
    
    # 然后才询问确认
    read -p "是否立即启动服务? (Y/n): " confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        echo "已取消"
        exit 0
    fi
    
    run_service
}

main
