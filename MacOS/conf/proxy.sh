#!/usr/bin/env bash

# Clear any proxy first
unset http_proxy https_proxy

# Detect proxy from macOS system settings
proxy_address=$(scutil --proxy | awk '/HTTPProxy/ {print $3}')
proxy_port=$(scutil --proxy | awk '/HTTPPort/ {print $3}')
pac_url=$(scutil --proxy | awk -F' : ' '/ProxyAutoConfigURLString/ {print $2}')

# Function to clear proxy and use direct connection
clear_proxy() {
    unset http_proxy https_proxy
    echo "❌ Proxy unreachable. Using direct connection."
}

# If manual proxy is detected, check connectivity
if [[ -n "$proxy_address" && -n "$proxy_port" ]]; then
    echo "Checking proxy connectivity: $proxy_address:$proxy_port..."
    
    # Ping proxy once and check if it's reachable
    if ping -c 1 -W 1 "$proxy_address" &>/dev/null; then
        export http_proxy="http://$proxy_address:$proxy_port"
        export https_proxy="http://$proxy_address:$proxy_port"
        echo "✅ Proxy reachable. Using: $http_proxy"
    else
        clear_proxy
    fi
else
    echo "No manual proxy detected. Checking PAC file..."
    
    # If PAC file exists, try to fetch it
    if [[ -n "$pac_url" ]]; then
        echo "PAC File Detected: $pac_url"
        
        pac_content=$(curl -s --max-time 2 "$pac_url")

        if [[ -n "$pac_content" ]]; then
            last_proxy=$(echo "$pac_content" | grep -oiE 'PROXY [^ ;]+' | awk '{print $2}' | tail -n 1)

            if [[ -n "$last_proxy" ]]; then
                echo "Checking PAC Proxy connectivity: $last_proxy..."
                proxy_host=$(echo "$last_proxy" | cut -d':' -f1)

                if ping -c 1 -W 1 "$proxy_host" &>/dev/null; then
                    export http_proxy="http://$last_proxy"
                    export https_proxy="http://$last_proxy"
                    echo "✅ PAC Proxy reachable. Using: $http_proxy"
                else
                    clear_proxy
                fi
            else
                echo "No valid proxies found in PAC file."
                clear_proxy
            fi
        else
            echo "Failed to retrieve PAC file."
            clear_proxy
        fi
    else
        echo "No PAC URL detected."
        clear_proxy
    fi
fi
