#!/usr/bin/env bash

# Welcome to nemafetch.
# You are more than welcome to change, modify, and distribute any part of this script. 

###############################################


# Colors - feel free to change them as you want 
HEADER_COLOR='\e[94m'
LABEL_COLOR='\e[96m'
VALUE_COLOR='\e[0m'
RESET='\e[0m'
YELLOW_COLOR='\e[93m' 


###############################################


#-------- Box  --------

truncate_str() {
    local input="$1"
    local max="$2"
    local len=${#input}
    if [ "$len" -le "$max" ]; then
        printf "%-${max}s" "$input"
    else
        local truncated_length=$((max - 2))
        printf "%s.." "${input:0:$truncated_length}"
    fi
}

total_width=54
inside_width=$((total_width - 2))

print_line() {
    local text="$1"
    printf "|%-${inside_width}s|\n" "$(truncate_str "$text" "$inside_width")"
}

print_colored_label() {
    local label="$1"
    local value="$2"

    local label_with_spaces="   ${label}: "
    local label_length=${#label_with_spaces}
    local total_content_width=50

    local value_max_len=$((total_content_width - label_length))
    (( value_max_len < 0 )) && value_max_len=0

    local truncated_value
    truncated_value=$(truncate_str "$value" "$value_max_len")

    local plain_line="${label_with_spaces}${truncated_value}"

    printf "| "
    printf "${LABEL_COLOR}%s${RESET}" "${plain_line:0:label_length}"
    printf "${VALUE_COLOR}%s" "${plain_line:label_length}"
    local current_len=${#plain_line}
    if (( current_len < total_content_width )); then
        printf "${VALUE_COLOR}%*s" $(( total_content_width - current_len )) ""
    fi
    printf "${RESET} |\n"
}

print_section_header() {
    local header="$1"
    local total_content_width=$inside_width

    local plain_line="$header"
    local current_len=${#plain_line}
    if (( current_len > total_content_width )); then
        plain_line="${plain_line:0:total_content_width}"
        current_len=$total_content_width
    fi

    printf "|"
    printf "${HEADER_COLOR}%s${RESET}" "$plain_line"
    if (( current_len < total_content_width )); then
        printf "%*s" $(( total_content_width - current_len )) ""
    fi
    printf "|\n"
}


print_sep() {
    printf "|"
    printf '%*s' "$inside_width" "" | tr ' ' '-'
    printf "|\n"
}


#-------- Package Managers Check --------

get_package_info() {
    declare -A pkg_counts
    if command -v dpkg >/dev/null 2>&1; then
        pkg_counts["apt/dpkg"]=$(dpkg --get-selections 2>/dev/null | wc -l)
    fi
    if command -v snap >/dev/null 2>&1; then
        pkg_counts["snap"]=$(snap list 2>/dev/null | tail -n +2 | wc -l)
    fi
    if command -v apk >/dev/null 2>&1; then
        pkg_counts["apk"]=$(apk info 2>/dev/null | wc -l)
    fi
    if command -v pacman >/dev/null 2>&1; then
        pkg_counts["pacman"]=$(pacman -Q 2>/dev/null | wc -l)
    fi
    if command -v dnf >/dev/null 2>&1; then
        pkg_counts["dnf"]=$(dnf list installed 2>/dev/null | tail -n +2 | wc -l)
    fi

    local num_pkg=${#pkg_counts[@]}
    local result=""
    if [ "$num_pkg" -eq 0 ]; then
        result="N/A"
    elif [ "$num_pkg" -eq 1 ]; then
        for key in "${!pkg_counts[@]}"; do
            result="${pkg_counts[$key]} ($key)"
        done
    elif [ "$num_pkg" -eq 2 ]; then
        for key in "${!pkg_counts[@]}"; do
            result+="${pkg_counts[$key]} ($key)   "
        done
        result=$(echo "$result" | sed 's/[[:space:]]*$//')
    else
        local arr=()
        for key in "${!pkg_counts[@]}"; do
            arr+=("${pkg_counts[$key]}:$key")
        done
        IFS=$'\n' sorted=($(sort -t: -k1,1nr <<<"${arr[*]}"))
        unset IFS
        result="${sorted[0]%%:*} (${sorted[0]##*:})   ${sorted[1]%%:*} (${sorted[1]##*:})"
    fi
    echo "$result"
}

###############################################


#-------- User Info --------

if [ -n "$SUDO_USER" ]; then
    actual_user="$SUDO_USER"
else
    actual_user="$USER"
fi
user="${actual_user}@$(hostname)"

#-------- User Render Section --------

username="${user%@*}"
hostname="${user#*@}"

plain_line="   Hello: ${username}@${hostname}"
line_length=${#plain_line}
padding_length=$(( inside_width - line_length ))
padding=$(printf "%*s" "$padding_length" "")

printf " ____________________________________________________\n"
print_line ""
printf "|   ${HEADER_COLOR}Hello${RESET}: ${LABEL_COLOR}%s${RESET}${YELLOW_COLOR}@${RESET}%s%s|\n" "$username" "$hostname" "$padding"
print_line ""
print_sep


###############################################


#-------- System Info --------

os="$(grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d '"' -f2) $(uname -m)"
kernel=$(uname -r)
pkg_info=$(get_package_info)

if [ -n "$SUDO_USER" ]; then
    shell_path=$(getent passwd "$SUDO_USER" | cut -d: -f7)
    shell_name=$(basename "$shell_path")
else
    shell_name=$(basename "$SHELL")
fi

if [ "$shell_name" = "zsh" ] && [ -n "$ZSH_VERSION" ]; then
    shell_ver=${ZSH_VERSION#zsh }
elif [ "$shell_name" = "bash" ]; then
    shell_ver=$(bash --version 2>/dev/null | head -n1 | sed -E 's/^GNU bash, version ([^ ]+).*/\1/')
else
    shell_ver=$($shell_name --version 2>/dev/null | head -n1 | awk '{print $2}')
fi

de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-N/A}}"

if command -v xfconf-query >/dev/null 2>&1; then
    current_theme=$(xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null || echo "N/A")
    current_icons=$(xfconf-query -c xsettings -p /Net/IconThemeName 2>/dev/null || echo "N/A")
    current_font=$(xfconf-query -c xsettings -p /Gtk/FontName 2>/dev/null || echo "N/A")
elif command -v kreadconfig5 >/dev/null 2>&1; then
    current_theme=$(kreadconfig5 --file kdeglobals --group General --key ColorScheme 2>/dev/null || echo "N/A")
    current_icons=$(kreadconfig5 --file kdeglobals --group Icons --key Theme 2>/dev/null || echo "N/A")
    current_font=$(kreadconfig5 --file kdeglobals --group General --key font 2>/dev/null || echo "N/A")
elif command -v gsettings >/dev/null 2>&1; then
    current_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || echo "N/A")
    current_icons=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || echo "N/A")
    current_font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'" || echo "N/A")
else

    current_theme="N/A"
    current_icons="N/A"
    current_font="N/A"
fi

if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    session="Wayland"
elif [ -n "$DISPLAY" ]; then
    session="X11"
else
    session="Unknown"
fi


term=${TERM:-$(basename "$SHELL")}
if command -v fc-match >/dev/null 2>&1; then
    term_font=$(fc-match monospace | cut -d':' -f1)
else
    term_font="N/A"
fi

#-------- System Render Section --------

print_section_header " System:"
print_colored_label "OS" "$os"
print_colored_label "Kernel" "$kernel"
print_colored_label "Session" "$session"
print_colored_label "Packages" "$pkg_info"
print_colored_label "Shell" "$shell_name $shell_ver"
print_colored_label "DE" "$de"
print_colored_label "Theme" "$current_theme"
print_colored_label "Icons" "$current_icons"
[ -n "$term" ] && print_colored_label "Terminal" "$term"
[ -n "$term_font" ] && print_colored_label "Terminal Font" "$term_font"
[ -n "$current_font" ] && [ "$current_font" != "N/A" ] && print_colored_label "Font" "$current_font"
print_sep


###############################################


#-------- Hardware Info --------
host=$(cat /sys/devices/virtual/dmi/id/product_version 2>/dev/null || hostname)
cpu=$(grep 'model name' /proc/cpuinfo | uniq | cut -d ':' -f2 | xargs)
gpu=$(lspci 2>/dev/null | grep VGA | cut -d ':' -f3 | cut -d '(' -f1 | xargs)
res=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}')
mem_total=$(free -h | awk '/Mem:/ {print $2}')
mem_used=$(free -h | awk '/Mem:/ {print $3}')
mem_free=$(free -h | awk '/Mem:/ {print $4}')
swap_total=$(free -h | awk '/Swap:/ {print $2}')
swap_used=$(free -h | awk '/Swap:/ {print $3}')
swap_free=$(free -h | awk '/Swap:/ {print $4}')
disk_total=$(df -h --total 2>/dev/null | awk '/total/ {print $2}')
disk_used=$(df -h --total 2>/dev/null | awk '/total/ {print $3}')
disk_free=$(df -h --total 2>/dev/null | awk '/total/ {print $4}')

#-------- Hardware Render Section --------

print_section_header " Hardware:"
[ -n "$host" ] && print_colored_label "Host" "$host"
[ -n "$cpu" ] && print_colored_label "CPU" "$cpu"
[ -n "$gpu" ] && print_colored_label "GPU" "$gpu"
[ -n "$res" ] && print_colored_label "Resolution" "$res"
print_colored_label "Ram" "                 Swap:"
print_colored_label "   Total" "$mem_total         Total: $swap_total"
print_colored_label "   Used" "$mem_used          Used:  $swap_used"
print_colored_label "   Free" "$mem_free         Free: $swap_free"
print_colored_label "Disk space" ""
print_colored_label "   Total" "$disk_total"
print_colored_label "   Used" "$disk_used"
print_colored_label "   Free" "$disk_free"
print_line ""
print_sep


###############################################


#-------- Network Info --------
if command -v nmcli >/dev/null 2>&1; then
    wifi=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes" {print $2; exit}')
    [ -z "$wifi" ] && wifi="N/A"
    vpn=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="vpn" {print $1; exit}')
    if [ -z "$vpn" ]; then
        vpn_iface=$(ip link show 2>/dev/null | grep -E 'tun0|wg0|ppp0' | awk -F: '{print $2}' | head -n1 | tr -d ' ')
        [ -n "$vpn_iface" ] && vpn="VPN ($vpn_iface)" || vpn="N/A"
    fi
else
    wifi="N/A"
    vpn="N/A"
fi

#-------- Network Render Section --------

if [ "$wifi" != "N/A" ] || [ "$vpn" != "N/A" ]; then
    print_section_header " Network:"
    [ "$wifi" != "N/A" ] && print_colored_label "Connected to WiFi" "$wifi"
    [ "$vpn" != "N/A" ] && print_colored_label "VPN" "$vpn"
    print_sep
fi