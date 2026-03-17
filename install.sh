#!/bin/bash

# ============================================================================
# 配置区
# ============================================================================
GITHUB_URL="https://github.com/你的用户名/项目名/releases/latest/download/example.tar.gz"
WORK_DIR="/root/.example_proxy"
BINARY_NAME="example"
ARCHIVE_NAME="example.tar.gz"

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
        # 直接从终端读取，避免管道问题
        read -p "请输入网盘地址 (必须): " address </dev/tty
        
        # 清理输入：去除前后空格和换行符
        address=$(echo -n "$address" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
        
        if [[ -n "$address" ]]; then
            break
        fi
        echo "错误: 地址不能为空，请重新输入"
    done
    
    # 必须参数：token
    while true; do
        read -p "请输入token (必须): " token </dev/tty
        token=$(echo -n "$token" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
        
        if [[ -n "$token" ]]; then
            break
        fi
        echo "错误: token不能为空"
    done
    
    # 可选参数：端口
    read -p "请输入监听端口 (默认: 5243): " user_port </dev/tty
    user_port=$(echo -n "$user_port" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
    port="${user_port:-5243}"
    
    # 可选参数：HTTPS
    read -p "是否启用HTTPS? (y/N): " use_https </dev/tty
    use_https=$(echo -n "$use_https" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
    
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
        read -p "是否使用此文件? (Y/n): " confirm </dev/tty
        confirm=$(echo -n "$confirm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
        
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
        read -p "是否使用此文件? (Y/n): " confirm </dev/tty
        confirm=$(echo -n "$confirm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
        
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
        read -p "请输入证书文件路径: " cert_path </dev/tty
        cert_path=$(echo -n "$cert_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
        
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
        read -p "请输入密钥文件路径: " key_path </dev/tty
        key_path=$(echo -n "$key_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
        
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
    cmd_args=$(build_command)
    
    echo "执行命令:"
    echo "./$BINARY_NAME $cmd_args"
    echo ""
    
    ./"$BINARY_NAME" $cmd_args
}

create_systemd_service() {
    echo ""
    echo "=== 创建systemd服务（开机自启）==="
    
    # 构建ExecStart命令
    local exec_cmd="$WORK_DIR/$BINARY_NAME"
    exec_cmd="$exec_cmd -address \"$address\""
    exec_cmd="$exec_cmd -token \"$token\""
    
    if [[ "$https_enabled" == "true" ]]; then
        exec_cmd="$exec_cmd -cert $WORK_DIR/server.crt"
        exec_cmd="$exec_cmd -https true"
        exec_cmd="$exec_cmd -key $WORK_DIR/server.key"
    fi
    
    if [[ "$port" != "5243" ]]; then
        exec_cmd="$exec_cmd -port $port"
    fi
    
    # 创建服务文件
    sudo tee /etc/systemd/system/example-proxy.service > /dev/null << EOF
[Unit]
Description=Example Proxy Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$WORK_DIR
ExecStart=/bin/bash -c "$exec_cmd"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable example-proxy.service
    
    echo "✅ systemd服务已创建"
    echo "   启动: sudo systemctl start example-proxy"
    echo "   停止: sudo systemctl stop example-proxy"
    echo "   状态: sudo systemctl status example-proxy"
}

create_shortcut() {
    echo ""
    echo "=== 创建快捷命令 ==="
    
    # 创建/usr/local/bin下的脚本
    sudo tee /usr/local/bin/example-proxy > /dev/null << EOF
#!/bin/bash
WORK_DIR="$WORK_DIR"
cd "\$WORK_DIR" || exit 1
exec "\$WORK_DIR/$BINARY_NAME" "\$@"
EOF

    sudo chmod +x /usr/local/bin/example-proxy
    echo "✅ 快捷命令已创建"
    echo "   使用: example-proxy"
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
    read -p "是否立即启动服务? (Y/n): " confirm </dev/tty
    confirm=$(echo -n "$confirm" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
    
    if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
        run_service
        
        # 创建快捷命令（总是创建）
        create_shortcut
        
        # 询问是否创建服务
        echo ""
        read -p "是否创建开机自启服务? (y/N): " create_service </dev/tty
        create_service=$(echo -n "$create_service" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n\r')
        
        if [[ "$create_service" == "y" || "$create_service" == "Y" ]]; then
            create_systemd_service
        fi
        
        echo ""
        echo "安装完成！"
    else
        echo "已取消"
        exit 0
    fi
}

# ============================================================================
# 脚本入口
# ============================================================================
if [[ $EUID -ne 0 ]]; then
    echo "错误: 此脚本需要以root用户运行"
    echo "请使用: sudo $0"
    exit 1
fi

main
