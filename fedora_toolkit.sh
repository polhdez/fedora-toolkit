#!/usr/bin/env bash
set -Euo pipefail

# ----- Functions with the tweaks. Feel free to reuse them ------

# Fedora 44
install_brave_origin() {
    [ "$(dnf repolist | grep brave-browser | cut -d ' ' -f1)" == "brave-browser" ] && return
    dnf install -y dnf-plugins-core
    dnf config-manager addrepo \
        --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    dnf install -y brave-origin
}

# Add RPMFusion
setup_rpmfusion() {
    dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    dnf config-manager setopt fedora-cisco-openh264.enabled=1
    dnf update -y @core
    dnf install -y rpmfusion-\*-appstream-data
}

# Add terra repo from ultramarine project
setup_terra() {
    [ "$(dnf repolist | grep terra | cut -d ' ' -f1)" == "terra" ] && return
    dnf install -y --nogpgcheck \
        --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
}

# Add virt-manager
install_virt_manager() {
    dnf install -y @virtualization
    dnf install -y virt-manager
    usermod -aG libvirt $(logname)
    systemctl enable --now libvirtd.service
}

# VSCode
install_vscode() {
    rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo
    dnf install -y code
}

# WIP
setup_h264() {
    dnf swap ffmpeg-free ffmpeg --allowerasing
    sudo dnf install @multimedia --setopt="install_weak_deps=False" \
        --exclude=PackageKit-gstreamer-plugin
    # Only NVIDIA
    #dnf install libva-nvidia-driver
}

# Installs zsh with my custom minimal config and starship prompt
# Tries to get starship from terra repos first, falls back to COPR
setup_zsh() {
	dnf install -y zsh \
		zsh-syntax-highlighting \
		zsh-autosuggestions
	git clone https://github.com/zsh-users/zsh-history-substring-search /usr/share/zsh-history-substring-search || true
    # If its missing from the repos add COPR
    dnf install -y starship || dnf copr enable -y atim/starship && dnf install -y starship
	chsh -s /usr/bin/zsh $(logname)
    local zshrc_path="/home/$(logname)/.zshrc"
    [[ ! -f ".zshrc" || -f "$zshrc_path" ]] &&
        curl -fsSL https://raw.githubusercontent.com/polhdez/fedora-toolkit/refs/heads/dev/.zshrc -o "${PWD}/.zshrc"
    # Avoid copy if the user ran script at home dir
    [[ "${PWD}/.zshrc" != "$zshrc_path" ]] &&
        cp "${PWD}/.zshrc" "$zshrc_path"
    chmod 750 "$zshrc_path"
    chown $(logname):$(logname) "$zshrc_path"
}

setup_ioschedulers() {
    cat << 'EOF' > /etc/udev/rules.d/60-ioschedulers.rules
# HDD (rotational drives) - use mq-deadline for better performance
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"

# SSD (non-rotational drives) - use mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

# NVMe SSD - use 'none' for best performance
# NVMe drives have their own advanced queue management and don't benefit from additional scheduling
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
EOF
udevadm control --reload-rules
udevadm trigger
}

# Enables parallel downloads to DNF to improve download speed
enable_dnf_parallel() {
	dnf config-manager setopt max_parallel_downloads=10
}

# Using the json NVIDIA database from 
# https://raw.githubusercontent.com/RightNow-AI/RightNow-GPU-Database/main/data/nvidia/all.json'
# autodetect NVIDIA architecture and install matching drivers for it
nvidia_autodetect_driver() {
    [ ! -f "nvidia-gpus.json" ] &&
        curl -fsSL \
        'https://raw.githubusercontent.com/polhdez/fedora-toolkit/refs/heads/dev/nvidia-gpus.json' \
        -o nvidia-gpus.json
	local model="$(lspci | grep -m1 NVIDIA | awk -F '[][]' '{print $2}')"
	[ -z "$model" ] && return
	local arch="$(cat nvidia-gpus.json | jq -r '[.[] | select(.name | contains("'"$model"'")).architecture] | first')"
	case $arch in
                Kepler) install_nvidia_driver_470; install_cuda ;;
                Maxwell|Pascal|Volta) install_nvidia_driver_580; install_cuda ;;
                Turing|Ampere) install_nvidia_driver_open; install_cuda  ;;
    esac
}

# Recommended driver for Turing+
install_nvidia_driver_open() {
    dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
}

# Driver for Turing Pascal and Volta architecture
install_nvidia_driver_580() {
    dnf install -y \
        xorg-x11-drv-nvidia-580xx akmod-nvidia-580xx xorg-x11-drv-nvidia-580xx-cuda
}

# Legacy driver for Kepler
install_nvidia_driver_470() {
    dnf install -y xorg-x11-drv-nvidia-470xx akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx-cuda
}

# Gets CUDA from the nvidia dev repos and sets up the needed ENV variables
install_cuda() {
    dnf config-manager addrepo \
        --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora44/$(uname -m)/cuda-fedora44.repo || true
    dnf clean all
    dnf config-manager setopt \
        cuda-fedora44-$(uname -m).exclude=nvidia-driver,nvidia-modprobe,nvidia-persistenced,nvidia-settings,nvidia-libXNVCtrl,nvidia-xconfig
    dnf -y install cuda-toolkit xorg-x11-drv-nvidia-cuda
    cat << 'EOF' > /etc/profile.d/cuda-toolkit.sh 
if [[ -d /usr/local/cuda ]]; then
    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
fi
EOF
}

# We add bazaar, it's a lot faster and stable
enable_flathub() {
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y io.github.kolunmi.Bazaar
}

# This is needed because we run the tool as root
gsettings_wrapper() {
    user="$(logname)"
    uid="$(id -u "$user")"
    bus_path="/run/user/$uid/bus"
    sudo -Hu "$user" env \
        "XDG_RUNTIME_DIR=/run/user/$uid" \
        "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus_path" \
        gsettings "$@"
}

# We get the adw-gtk3 from fedora's repos and if we have flatpak available
# then get the corresponding flatpak packages
install_adw-gtk3() {
    dnf install -y adw-gtk3-theme
    if command -v flatpak; then
        flatpak install -y org.fedoraproject.Gtk3theme.adw-gtk3
    fi
    if [ "$(gsettings_wrapper get org.gnome.desktop.interface color-scheme | tail -n 1)" == ''\''prefer-dark'\''' ]; then
        gsettings_wrapper set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
        gsettings_wrapper set org.gnome.desktop.interface color-scheme prefer-dark
    else
        gsettings_wrapper set org.gnome.desktop.interface gtk-theme adw-gtk3
    fi
}

# Workaround to enable the extensions from the root user
enable_system_gnome_extension() {
    extension_id="$1"
    extension_list="$(gsettings_wrapper get org.gnome.shell enabled-extensions)"

    if [[ "$extension_list" == "@as []" ]]; then
        new_list="['$extension_id']"
    else
        new_list="${extension_list::-1}, '$extension_id']"
    fi
    gsettings_wrapper set org.gnome.shell enabled-extensions "$new_list"
}

enable_window_buttons() {
    gsettings_wrapper set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
}

install_gnome_extensions() {
    dnf install -y gnome-tweaks gnome-extensions-app \
                gnome-shell-extension-appindicator \
                gnome-shell-extension-dash-to-dock
    enable_system_gnome_extension dash-to-dock@micxgx.gmail.com
    enable_system_gnome_extension appindicatorsupport@rgcjonas.gmail.com   
}

apply_everything() {
    # Improve dnf speed
    enable_dnf_parallel
    # Update first
    dnf update -y
    # Extra repositories
    setup_rpmfusion
    setup_terra
    enable_flathub
    # Add applications
    install_brave_origin
    install_vscode
    install_virt_manager
    # Install zsh config
    setup_zsh
    # Gnome tweaks
    enable_window_buttons
    install_gnome_extensions
    install_adw-gtk3
    # Setup NVIDIA driver (if we find GPU)
    nvidia_autodetect_driver
}

# ------ TUI Section ------

# Global variables
selection=0
n_options=0

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ESC char
ESC='\033[K'

# Helper functions for the menus
selection_prev() {
    if [ $selection -ge 0 ] && [ $selection -lt $(($n_options - 1)) ]; then
        selection=$(($selection + 1))
    fi
}

selection_next() {
    if [ $selection -gt 0 ] && [ $selection -lt $(($n_options)) ]; then
        selection=$(($selection - 1))
    fi
}

read_key() {
    # Source - https://stackoverflow.com/a/46481173
    # Posted by Jellicle, modified by community. See post 'Timeline' for change history
    # Retrieved 2026-09-16, License - CC BY-SA 4.0

    local escape_char=$(printf "\u1b")
    local mode
    read -N1 mode # get 1 character
    if [[ $mode == $escape_char ]]; then
        read -n2 mode # read 2 more chars
    fi
    case $mode in
        'q') exit 0;;
        '[A') selection_next ;; # Up arrow
        '[B') selection_prev  ;; # Down arrow
        '[D') selection_next ;; # Left arrow
        '[C') selection_prev  ;; # Right arrow
        $'\x0a') return 0;; #Enter key
        *) >&2 echo 'ERR bad input'; return 1;;
    esac
    return 1
}

print_banner() {
    echo -en $CYAN
    cat << EOF

  ⣏⡉ ⢀⡀ ⢀⣸ ⢀⡀ ⡀⣀ ⢀⣀ 
  ⠇  ⠣⠭ ⠣⠼ ⠣⠜ ⠏  ⠣⠼ 
  ⣰⡀ ⢀⡀ ⢀⡀ ⡇ ⡇⡠ ⠄ ⣰⡀
  ⠘⠤ ⠣⠜ ⠣⠜ ⠣ ⠏⠢ ⠇ ⠘⠤

EOF
echo -en $NC
}

# Main logic with tput magic so the interface looks good
draw_selection_list() {
    options=("$@")
    n_options="${#options[@]}"
    while true; do
        tput cup 0 0
        print_banner
        for i in "${!options[@]}"; do            
            if [ "$i" == "$selection" ]; then
                echo -en "➤${CYAN}${options[$i]}${NC}"
            else
                echo -en " ${options[$i]}${ESC}"
            fi
            tput el
            echo
        done
        tput ed
        if read_key; then
            return
        fi
    done
}

draw_ask_dialog() {
    msg="$1"
    shift
    options=("$@")
    n_options="${#options[@]}"
    while true; do
        tput cup 0 0
        print_banner
        echo "$msg"
        tput el
        echo 
        line=""
        for i in "${!options[@]}"; do            
            if [ "$i" == "$selection" ]; then
                line+="${CYAN}[${options[$i]}]${NC} "
            else
                line+="${options[$i]}${ESC} "
            fi
        done
        echo -e $line
        tput el
        tput ed
        if read_key; then
            return
        fi
    done
}

finished_msg() {
    local msg="${GREEN}Task ran succesfully!${NC}"
    [ "$1" != "" ] && msg="$1"
    echo -en "$msg"
    read -p " Press any key to return."
    # Disable cursor key echo etc
    tput cup 0 0
    tput ed
    stty -echo
    tput civis
}

# ----- The actual menus for the tool ------

everything_menu() {
    selection=0
    options=(
        "Yes"
        "No"
    )
    draw_ask_dialog "Do you really want to apply all the features and tweaks?" "${options[@]}"
    case $selection in
        '0') apply_everything;;
        '1') main_menu;;
    esac
    finished_msg "${GREEN}Finished! A reboot is recommended!${NC}"
    main_menu
}

shell_menu() {
    selection=0
    options=(
        "Install fish-like zsh config"
        "Back"
   )
   draw_selection_list "${options[@]}"
    case $selection in
        '0') setup_zsh;;
        '1') main_menu;;
    esac
    finished_msg
    main_menu
}

performance_menu() {
    selection=0
    options=(
        "Enable dnf parallel downloads"
        "Set up udev rule for optimal I/O scheduling"
        "Back"
   )
   draw_selection_list "${options[@]}"
    case $selection in
        '0') enable_dnf_parallel;;
        '1') setup_ioschedulers;;
        '2') main_menu;;
    esac
    finished_msg
    main_menu
}

apps_menu() {
    selection=0; 
    options=(
        "Install Brave Origin"
        "Install VSCode"
        "Install Virt-Manager"
        "Back"
    )
    draw_selection_list "${options[@]}"
    case $selection in
        '0') install_brave_origin;;
        '1') install_vscode;;
        '2') install_virt_manager;;
        '3') main_menu;;
    esac
    finished_msg
    main_menu
}

nvidia_menu() {
    selection=0
    options=(
        "Autodetect and install NVIDIA drivers"
        "Install NVIDIA current driver"
        "Install NVIDIA 580"
        "Install NVIDIA 470"
        "Install CUDA"
        "Back"
    )
    draw_selection_list "${options[@]}"
    case $selection in
        '0') nvidia_autodetect_driver;;
        '1') install_nvidia_driver_open;;
        '2') install_nvidia_driver_580;;
        '3') install_nvidia_driver_470;;
        '4') install_cuda;;
        '5') main_menu;;
    esac
    finished_msg
    main_menu
}

repos_menu() {
    selection=0
    options=(
        "Setup RPMFusion"
        "Setup Terra Repository"
        "Setup Flathub"
        "Back"
    )
    draw_selection_list "${options[@]}"
    case $selection in
        '0') setup_rpmfusion;;
        '1') setup_terra;;
        '2') enable_flathub;;
        '3') main_menu;;
    esac
    finished_msg
    main_menu
}

gnome_tweaks_menu() {
    selection=0
    options=(
        "Enable window buttons"
        "Install basic extensions"
        "Install libadwaita GTK3 theme (adw-gtk3)"
        "Back"
    )
    draw_selection_list "${options[@]}"
    case $selection in
        '0') enable_window_buttons;;
        '1') install_gnome_extensions;;
        '2') install_adw-gtk3;;
        '3') main_menu;;
    esac
    finished_msg
    main_menu
}

main_menu() {
    selection=0
    options=(
        "Apply everything! (opinionated, check README)"
        "NVIDIA Drivers ->"
        "Applications ->"
        "Performance tweaks ->"
        "Repositories ->"
        "Gnome tweaks ->"
        "Shell ->"
        "Exit"
    )
    draw_selection_list "${options[@]}"
    case $selection in
        '0') everything_menu;;
        '1') nvidia_menu;;
        '2') apps_menu;;
        '3') performance_menu;;
        '4') repos_menu;;
        '5') gnome_tweaks_menu;;
        '6') shell_menu;;
        '7') exit;;
    esac
    main_menu
}

update_dialog() {
    selection=0
    options=(
        "Yes"
        "No"
    )
    draw_ask_dialog "It is recommended to update the system before running. Update now?" "${options[@]}"
    case $selection in
        '0') dnf -y update;;
        '1') main_menu;;
    esac
    clear
    main_menu
}

if [ $(id -u) != 0 ]; then
    echo "Run the script as root!"
    exit 1
fi

# Disable echo and cursor. Restore on exit
stty -echo
tput civis

cleanup() {
    stty echo
    tput cnorm
    exit
}

handle_err() {
    echo -e "${RED}Task failed! Check the logs${NC}"
    cleanup
}

trap 'cleanup' EXIT INT TERM
trap 'handle_err' ERR
clear
update_dialog
main_menu
