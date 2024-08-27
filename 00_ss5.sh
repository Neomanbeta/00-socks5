#!/bin/bash
export LC_ALL=C
export UUID=${UUID:-'39e8b439-06be-4783-ad52-6357fc5e8743'}         
export NEZHA_SERVER=${NEZHA_SERVER:-''}             
export NEZHA_PORT=${NEZHA_PORT:-'5555'}            
export NEZHA_KEY=${NEZHA_KEY:-''}
export PASSWORD=${PASSWORD:-'admin'} 
export PORT=${PORT:-'0000'}
export SOCKSU=${SOCKSU:-'oneforall'}
export SOCKSP=${SOCKSP:-'allforone'}
export STCP=${STCP:-'0000'}
export SUDP=${SUDP:-'0000'}  
USERNAME=$(whoami)
HOSTNAME=$(hostname)

[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="domains/${USER,,}.ct8.pl/logs" || WORKDIR="domains/${USERNAME}.serv00.net/logs"
[ -d "$WORKDIR" ] || (mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR" && cd "$WORKDIR")
ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk '{print $2}' | xargs -r kill -9

# Download Dependency Files
clear
echo -e "\e[1;35m正在安装中,请稍等...\e[0m"
ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd.sha256sum web" "https://github.com/eooce/test/releases/download/ARM/swith npm")
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    FILE_INFO=("https://github.com/etjec4/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-unknown-freebsd web" "https://github.com/Neomanbeta/00-socks5/releases/download/freebsd-amd64/ss5 ss5" "https://github.com/eooce/test/releases/download/freebsd/swith npm")
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

download_with_fallback() {
    local URL=$1
    local NEW_FILENAME=$2

    curl -L -sS --max-time 3 -o "$NEW_FILENAME" "$URL" &
    CURL_PID=$!
    CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    sleep 1

    CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
        kill $CURL_PID
        wait $CURL_PID 2>/dev/null
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloading $NEW_FILENAME with wget\e[0m"
    else
        wait $CURL_PID
        echo -e "\e[1;32mDownloading $NEW_FILENAME with curl\e[0m"
    fi
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    if [ -e "$NEW_FILENAME" ]; then
        echo -e "\e[1;32m$NEW_FILENAME already exists, Skipping download\e[0m"
    else
        download_with_fallback "$URL" "$NEW_FILENAME"
    fi
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

# Generate cert
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout $WORKDIR/server.key -out $WORKDIR/server.crt -subj "/CN=bing.com" -days 36500

# Generate configuration file
cat > config.json <<EOL
{
  "server": "[::]:$PORT",
  "users": {
    "$UUID": "$PASSWORD"
  },
  "certificate": "$WORKDIR/server.crt",
  "private_key": "$WORKDIR/server.key",
  "congestion_control": "bbr",
  "alpn": ["h3", "spdy/3.1"],
  "udp_relay_ipv6": true,
  "zero_rtt_handshake": false,
  "dual_stack": true,
  "auth_timeout": "3s",
  "task_negotiation_timeout": "3s",
  "max_idle_time": "10s",
  "max_external_packet_size": 1500,
  "gc_interval": "3s",
  "gc_lifetime": "15s",
  "log_level": "warn"
}
EOL

# Generate ss5 configuration file
cat > ss5.json <<EOL
{
    "ListenPort": $STCP,
    "TCPListen": "",
    "UDPListen": "127.0.0.1:$SUDP",
    "UDPAdvertisedIP": "",
    "UserName": "$SOCKSU",
    "Password": "$SOCKSP",
    "UDPTimout": 60,
    "TCPTimeout": 60,
    "LogLevel": "error"
}
EOL

# running files
run() {
  if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
    tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
    if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
      NEZHA_TLS="--tls"
    else
      NEZHA_TLS=""
    fi
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
      export TMPDIR=$(pwd)
      nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
      sleep 1
      pgrep -x "$(basename ${FILE_MAP[npm]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[npm]}) is running\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[npm]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[npm]})" && nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m"$(basename ${FILE_MAP[npm]})" restarted\e[0m"; }
    else
      echo -e "\e[1;35mNEZHA variable is empty, skipping running\e[0m"
    fi
  fi

  if [ -e "$(basename ${FILE_MAP[web]})" ]; then
    nohup ./"$(basename ${FILE_MAP[web]})" -c config.json >/dev/null 2>&1 &
    sleep 1
    pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) is running\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[web]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[web]})" && nohup ./"$(basename ${FILE_MAP[web]})" -c config.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) restarted\e[0m"; }
  fi

  if [ -e "$(basename ${FILE_MAP[ss5]})" ]; then
    nohup ./"$(basename ${FILE_MAP[ss5]})" -c ss5.json >/dev/null 2>&1 &
    sleep 1
    pgrep -x "$(basename ${FILE_MAP[ss5]})" > /dev/null && echo -e "\e[1;32m$(basename ${FILE_MAP[ss5]}) is running\e[0m" || { echo -e "\e[1;35m$(basename ${FILE_MAP[ss5]}) is not running, restarting...\e[0m"; pkill -f "$(basename ${FILE_MAP[ss5]})" && nohup ./"$(basename ${FILE_MAP[ss5]})" -c ss5.json >/dev/null 2>&1 & sleep 2; echo -e "\e[1;32m$(basename ${FILE_MAP[ss5]}) restarted\e[0m"; }
  fi
rm -rf "$(basename ${FILE_MAP[web]})" "$(basename ${FILE_MAP[npm]})" "$(basename ${FILE_MAP[ss5]})"
}
run

get_ip() {
  ip=$(curl -s --max-time 2 ipv4.ip.sb)
  if [ -z "$ip" ]; then
      ip=$( [[ "$HOSTNAME" =~ s[0-9]\.serv00\.com ]] && echo "${HOSTNAME/s/web}" || echo "$HOSTNAME" )
  else
      accessible=false
      response=$(ping -c 3 -W 3 www.baidu.com)
      if echo "$response" | grep -q "time="; then
          accessible=true
      fi
      if [ "$accessible" = false ]; then
          ip=$( [[ "$HOSTNAME" =~ s[0-9]\.serv00\.com ]] && echo "${HOSTNAME/s/web}" || echo "$ip" )
      fi
  fi
  echo "$ip"
}

HOST_IP=$(get_ip)
echo -e "\e[1;32m本机IP: $HOST_IP\033[0m"
ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g')
echo -e "\e[1;32mTuic和Socks5安装成功\033[0m\n"
echo -e "\e[1;33mTuic在V2rayN 或 Nekobox，跳过证书验证需设置为true，不要把socks5作为节点添加到代理软件里！\033[0m\n"
echo -e "\e[1;32mtuic://$UUID:$PASSWORD@$HOST_IP:$PORT?congestion_control=bbr&alpn=h3&sni=www.bing.com&udp_relay_mode=native&allow_insecure=1#$ISP\e[0m\n"
echo -e "\e[1;32msocks5://$SOCKSU:$SOCKSP@$HOST_IP:$STCP#$ISP\e[0m\n"
echo -e "\e[1;33mClash\033[0m"
cat << EOF
- name: $ISP
  type: tuic
  server: $HOST_IP
  port: $PORT                                                          
  uuid: $UUID
  password: $PASSWORD
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: www.bing.com                                
  skip-cert-verify: true
EOF
rm -rf config.json ss5.json fake_useragent_0.2.0.json
echo -e "\n\e[1;32mRuning done!\033[0m"
echo -e "\e[1;35m脚本模板由老王原创，本脚本在老王原版上修改而来\e[0m"
echo -e "\e[1;35m如果碰到任何BUG，和老王无关\e[0m"
echo -e "\e[1;35m老王原脚本地址：https://github.com/eooce/Sing-box\e[0m"
echo -e "\e[1;35m转载请注明出处，请勿滥用\e[0m\n"
exit 0