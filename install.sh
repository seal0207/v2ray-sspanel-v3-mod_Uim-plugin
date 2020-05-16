#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=`pwd`
# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
software=(Docker_Caddy Docker_Caddy_cloudflare Docker)
operation=(安装 更新设置 更新镜像 查看日志)
# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 这个项目需要root权限！" && exit 1

#Check system
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
error_detect_depends(){
    local command=$1
    local depend=`echo "${command}" | awk '{print $4}'`
    echo -e "[${green}Info${plain}] 开始安装包 ${depend}"
    ${command} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] 安装失败 ${red}${depend}${plain}"
        echo "请自行百度、谷歌进行解决."
        exit 1
    fi
}

# Pre-installation settings
pre_install_docker_compose(){
    # Set ssrpanel_url
    echo "设置面板地址"
    read -p "(这里不能出错，请确你输入正确地址，默认https://www.selaplane.com):" ssrpanel_url
    [ -z "${ssrpanel_url}" ] && ssrpanel_url=https://www.selaplane.com
    echo
    echo "---------------------------"
    echo "面板网址 = ${ssrpanel_url}"
    echo "---------------------------"
    echo
    # Set ssrpanel key
    echo "设置面板key"
    read -p "这里不能输错，请确保输入正确:（默认：seal）" ssrpanel_key
    [ -z "${ssrpanel_key}" ]  && ssrpanel_key=seal
    echo
    echo "---------------------------"
    echo "面板key = ${ssrpanel_key}"
    echo "---------------------------"
    echo

    # Set ssrpanel speedtest function
    echo "设置节点测速周期"
    read -p "节点测速周期，默认为6小时执行一次:" ssrpanel_speedtest
    [ -z "${ssrpanel_speedtest}" ] && ssrpanel_speedtest=6
    echo
    echo "---------------------------"
    echo "节点测速周期 = ${ssrpanel_speedtest}"
    echo "---------------------------"
    echo

    # Set ssrpanel node_id
    echo "面板节点序号"
    read -p "面板节点序号默认为4:" ssrpanel_node_id
    [ -z "${ssrpanel_node_id}" ] && ssrpanel_node_id=4
    echo
    echo "---------------------------"
    echo "面板节点 = ${ssrpanel_node_id}"
    echo "---------------------------"
    echo

    # Set V2ray backend API Listen port
    echo "设置v2ray接口监听端口" 
    read -p "v2ray接口监听端口默认为2333:" v2ray_api_port
    [ -z "${v2ray_api_port}" ] && v2ray_api_port=2333
    echo
    echo "---------------------------"
    echo "V2ray API监听端口 = ${v2ray_api_port}"
    echo "---------------------------"
    echo

    # Set Setting if the node go downwith panel
    echo "设置流量监控下载节点序号"
    read -p "流量监控下载节点序号默认为1，请勿修改:" v2ray_downWithPanel
    [ -z "${v2ray_downWithPanel}" ] && v2ray_downWithPanel=1
    echo
    echo "---------------------------"
    echo "下载节点序号 = ${v2ray_downWithPanel}"
    echo "---------------------------"
    echo
}

pre_install_caddy(){

    # Set caddy v2ray domain
    echo "输入你的v2ray域名"
    read -p "(这里不能输错，请确认):" v2ray_domain
    [ -z "${v2ray_domain}" ]
    echo
    echo "---------------------------"
    echo "v2ray域名 = ${v2ray_domain}"
    echo "---------------------------"
    echo


    # Set caddy v2ray path
    echo "设置v2ray的路径"
    read -p "默认路径，默认为/sela/:" v2ray_path
    [ -z "${v2ray_path}" ] && v2ray_path="/sela/"
    echo
    echo "---------------------------"
    echo "v2ray路径 = ${v2ray_path}"
    echo "---------------------------"
    echo

    # Set caddy v2ray tls email
    echo "设置caddy-tls证书域名邮箱地址"
    read -p "(默认为：seal0207@gmail.com ):" v2ray_email
    [ -z "${v2ray_email}" ] && v2ray_email=seal0207@gmail.com
    echo
    echo "---------------------------"
    echo "v2ray邮箱 = ${v2ray_email}"
    echo "---------------------------"
    echo

    # Set Caddy v2ray listen port
    echo "设置caddy+v2ray本地监听端口"
    read -p "默认端口10550:" v2ray_local_port
    [ -z "${v2ray_local_port}" ] && v2ray_local_port=10550
    echo
    echo "---------------------------"
    echo "v2ray本地端口 = ${v2ray_local_port}"
    echo "---------------------------"
    echo

    # Set Caddy  listen port
    echo "设置caddy监听端口"
    read -p "默认端口：443:" caddy_listen_port
    [ -z "${caddy_listen_port}" ] && caddy_listen_port=443
    echo
    echo "---------------------------"
    echo "caddy监听端口 = ${caddy_listen_port}"
    echo "---------------------------"
    echo


}

# Config docker
config_docker(){
    echo "输入任意内容启动...或者执行CTRL+C 取消"
    char=`get_char`
    cd ${cur_dir}
    echo "安装 curl"
    install_dependencies
    echo "写入 docker-compose.yml"
    curl -L https://raw.githubusercontent.com/seal0207/v2ray-sspanel-v3-mod_Uim-plugin/master/Docker/V2ray/docker-compose.yml > docker-compose.yml
    sed -i "s|node_id:.*|node_id: ${ssrpanel_node_id}|"  ./docker-compose.yml
    sed -i "s|sspanel_url:.*|sspanel_url: '${ssrpanel_url}'|"  ./docker-compose.yml
    sed -i "s|key:.*|key: '${ssrpanel_key}'|"  ./docker-compose.yml
    sed -i "s|speedtest:.*|speedtest: ${ssrpanel_speedtest}|"  ./docker-compose.yml
    sed -i "s|api_port:.*|api_port: ${v2ray_api_port}|" ./docker-compose.yml
    sed -i "s|downWithPanel:.*|downWithPanel: ${v2ray_downWithPanel}|" ./docker-compose.yml
}


# Config caddy_docker
config_caddy_docker(){
    echo "输入任意内容启动...或者执行CTRL+C 取消"
    char=`get_char`
    cd ${cur_dir}
    echo "安装 curl"
    install_dependencies
    curl -L https://raw.githubusercontent.com/seal0207/v2ray-sspanel-v3-mod_Uim-plugin/master/Docker/Caddy_V2ray/Caddyfile >  Caddyfile
    echo "写入 docker-compose.yml"
    curl -L https://raw.githubusercontent.com/seal0207/v2ray-sspanel-v3-mod_Uim-plugin/master/Docker/Caddy_V2ray/docker-compose.yml > docker-compose.yml
    sed -i "s|node_id:.*|node_id: ${ssrpanel_node_id}|"  ./docker-compose.yml
    sed -i "s|sspanel_url:.*|sspanel_url: '${ssrpanel_url}'|"  ./docker-compose.yml
    sed -i "s|key:.*|key: '${ssrpanel_key}'|"  ./docker-compose.yml
    sed -i "s|speedtest:.*|speedtest: ${ssrpanel_speedtest}|"  ./docker-compose.yml
    sed -i "s|api_port:.*|api_port: ${v2ray_api_port}|" ./docker-compose.yml
    sed -i "s|downWithPanel:.*|downWithPanel: ${v2ray_downWithPanel}|" ./docker-compose.yml
    sed -i "s|V2RAY_DOMAIN=xxxx.com|V2RAY_DOMAIN=${v2ray_domain}|"  ./docker-compose.yml
    sed -i "s|V2RAY_PATH=/v2ray|V2RAY_PATH=${v2ray_path}|"  ./docker-compose.yml
    sed -i "s|V2RAY_EMAIL=xxxx@outlook.com|V2RAY_EMAIL=${v2ray_email}|"  ./docker-compose.yml
    sed -i "s|V2RAY_PORT=10550|V2RAY_PORT=${v2ray_local_port}|"  ./docker-compose.yml
    sed -i "s|V2RAY_OUTSIDE_PORT=443|V2RAY_OUTSIDE_PORT=${caddy_listen_port}|"  ./docker-compose.yml
}

# Config caddy_docker
config_caddy_docker_cloudflare(){

    # Set caddy cloudflare ddns email
    echo "caddy cloudflare ddns email"
    read -p "(无默认 ):" cloudflare_email
    [ -z "${cloudflare_email}" ]
    echo
    echo "---------------------------"
    echo "cloudflare_email = ${cloudflare_email}"
    echo "---------------------------"
    echo

    # Set caddy cloudflare ddns key
    echo "caddy cloudflare ddns key"
    read -p "(无默认 ):" cloudflare_key
    [ -z "${cloudflare_email}" ]
    echo
    echo "---------------------------"
    echo "cloudflare_email = ${cloudflare_key}"
    echo "---------------------------"
    echo
    echo

    echo "输入任意内容启动...或者执行CTRL+C 取消"
    char=`get_char`
    cd ${cur_dir}
    echo "install curl first "
    install_dependencies
    echo "启动并写入Caddy file and docker-compose.yml"
    curl -L https://raw.githubusercontent.com/seal0207/v2ray-sspanel-v3-mod_Uim-plugin/master/Docker/Caddy_V2ray/Caddyfile >Caddyfile
    epcho "写入 docker-compose.yml"
    curl -L https://raw.githubusercontent.com/seal0207/v2ray-sspanel-v3-mod_Uim-plugin/master/Docker/Caddy_V2ray/docker-compose.yml >docker-compose.yml
    sed -i "s|node_id:.*|node_id: ${ssrpanel_node_id}|"  ./docker-compose.yml
    sed -i "s|sspanel_url:.*|sspanel_url: '${ssrpanel_url}'|"  ./docker-compose.yml
    sed -i "s|key:.*|key: '${ssrpanel_key}'|"  ./docker-compose.yml
    sed -i "s|speedtest:.*|speedtest: ${ssrpanel_speedtest}|"  ./docker-compose.yml
    sed -i "s|api_port:.*|api_port: ${v2ray_api_port}|" ./docker-compose.yml
    sed -i "s|downWithPanel:.*|downWithPanel: ${v2ray_downWithPanel}|" ./docker-compose.yml
    sed -i "s|V2RAY_DOMAIN=xxxx.com|V2RAY_DOMAIN=${v2ray_domain}|"  ./docker-compose.yml
    sed -i "s|V2RAY_PATH=/v2ray|V2RAY_PATH=${v2ray_path}|"  ./docker-compose.yml
    sed -i "s|V2RAY_EMAIL=xxxx@outlook.com|V2RAY_EMAIL=${v2ray_email}|"  ./docker-compose.yml
    sed -i "s|V2RAY_PORT=10550|V2RAY_PORT=${v2ray_local_port}|"  ./docker-compose.yml
    sed -i "s|V2RAY_OUTSIDE_PORT=443|V2RAY_OUTSIDE_PORT=${caddy_listen_port}|"  ./docker-compose.yml
    sed -i "s|#      - CLOUDFLARE_EMAIL=xxxxxx@out.look.com|      - CLOUDFLARE_EMAIL=${cloudflare_email}|"  ./docker-compose.yml
    sed -i "s|#      - CLOUDFLARE_API_KEY=xxxxxxx|      - CLOUDFLARE_API_KEY=${cloudflare_key}|"  ./docker-compose.yml
    sed -i "s|# dns cloudflare|dns cloudflare|"  ./Caddyfile

}

# Install docker and docker compose
install_docker(){
    echo -e "启动并安装 Docker "
    curl -fsSL https://get.docker.com -o get-docker.sh
    bash get-docker.sh
    echo -e "启动并安装 Docker Compose "
    curl -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    curl -L https://raw.githubusercontent.com/docker/compose/1.8.0/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose
    clear
    echo "启动 Docker "
    service docker start
    echo "启动 Docker-Compose "
    docker-compose up -d
    echo
    echo -e "恭喜你，V2ray对接程序已经部署完成!"
    echo
    echo "劲情享受吧!"
    echo
}

install_check(){
    if check_sys packageManager yum || check_sys packageManager apt; then
        if centosversion 5; then
            return 1
        fi
        return 0
    else
        return 1
    fi
}

install_select(){
    clear
    while true
    do
    echo  "选择你要执行的Docker:"
    for ((i=1;i<=${#software[@]};i++ )); do
        hint="${software[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "请输入数字 (默认为 ${software[0]}):" selected
    [ -z "${selected}" ] && selected="1"
    case "${selected}" in
        1|2|3|4)
        echo
        echo "你选择的是 = ${software[${selected}-1]}"
        echo
        break
        ;;
        *)
        echo -e "[${red}Error${plain}] 请输入数字 [1-4]"
        ;;
    esac
    done
}
install_dependencies(){
    if check_sys packageManager yum; then
        echo -e "[${green}Info${plain}] 检查EPEL存储库..."
        if [ ! -f /etc/yum.repos.d/epel.repo ]; then
            yum install -y epel-release > /dev/null 2>&1
        fi
        [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Install EPEL repository failed, please check it." && exit 1
        [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils > /dev/null 2>&1
        [ x"$(yum-config-manager epel | grep -w enabled | awk '{print $3}')" != x"True" ] && yum-config-manager --enable epel > /dev/null 2>&1
        echo -e "[${green}Info${plain}] 检查完整的EPEL存储库..."

        yum_depends=(
             curl
        )
        for depend in ${yum_depends[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
    elif check_sys packageManager apt; then
        apt_depends=(
           curl
        )
        apt-get -y update
        for depend in ${apt_depends[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
    fi
    echo -e "[${green}Info${plain}] 设置时区为上海"
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"

}
#update_image
更新镜像_v2ray(){
    echo "结束程序"
    docker-compose down
    echo "拉取镜像"
    docker-compose pull
    echo "启动服务"
    docker-compose up -d
}

#show last 100 line log

查看日志_v2ray(){
    echo "历史100条日志情况"
    docker-compose logs --tail 100
}

# Update config
更新设置_v2ray(){
    cd ${cur_dir}
    echo "结束程序"
    docker-compose down
    install_select
    case "${selected}" in
        1)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker
        ;;
        2)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker_cloudflare
        ;;
        3)
        pre_install_docker_compose
        config_docker
        ;;
        *)
        echo "请输入正确的数字！"
        ;;
    esac

    echo "启动服务"
    docker-compose up -d

}
# remove config
# Install v2ray
安装_v2ray(){
    install_select
    case "${selected}" in
        1)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker
        ;;
        2)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker_cloudflare
        ;;
        3)
        pre_install_docker_compose
        config_docker
        ;;
        *)
        echo "请输入正确的数字！"
        ;;
    esac
    install_docker
}

# Initialization step
clear
while true
do
echo  "请选择你要进行的项目:"
for ((i=1;i<=${#operation[@]};i++ )); do
    hint="${operation[$i-1]}"
    echo -e "${green}${i}${plain}) ${hint}"
done
read -p "请输入数字 (默认为 ${operation[0]}):" selected
[ -z "${selected}" ] && selected="1"
case "${selected}" in
    1|2|3|4)
    echo
    echo "You choose = ${operation[${selected}-1]}"
    echo
    ${operation[${selected}-1]}_v2ray
    break
    ;;
    *)
    echo -e "[${red}Error${plain}] 请输入正确的数字！ [1-4]"
    ;;
esac
done
