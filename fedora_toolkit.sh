#!/usr/bin/env bash
set -euo pipefail

# Fedora 44
install_brave_origin() {
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
    dnf check-update
    dnf install code
}


setup_zsh() {
	dnf install -y zsh \
		zsh-syntax-highlighting \
		zsh-autosuggestions
	git clone https://github.com/zsh-users/zsh-history-substring-search /usr/share/zsh-history-substring-search || true
	dnf copr -y enable atim/starship
	dnf install -y starship
	chsh -s /usr/bin/zsh $(logname) 
	cat << 'EOF' > /home/$(logname)/.zshrc
typeset -g -A key
key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"
[[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"       beginning-of-line
[[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"        end-of-line
[[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"     overwrite-mode
[[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}"  backward-delete-char
[[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"     delete-char
[[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         up-line-or-history
[[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       down-line-or-history
[[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"       backward-char
[[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"      forward-char
[[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"     beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"   end-of-buffer-or-history
[[ -n "${key[Shift-Tab]}" ]] && bindkey -- "${key[Shift-Tab]}"  reverse-menu-complete
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

[[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         history-substring-search-up
[[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
	autoload -Uz add-zle-hook-widget
	function zle_application_mode_start { echoti smkx }
	function zle_application_mode_stop { echoti rmkx }
	add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
	add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi

# Plugins
ZSH_PLUGIN_DIR=/usr/share/
source $ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $ZSH_PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh
source $ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh
autoload -U compinit promptinit
export PATH=$PATH:~/.local/bin/
export SAVEHIST=10000
export HISTSIZE=10000
export HISTFILE=~/.zsh_history

compinit
zstyle ':completion:*' menu select

alias ll="ls -la"
alias cls=clear

eval "$(starship init zsh)"
EOF
}

# Install NVIDIA
install_nvidia_driver() {
    dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
}

install_nvidia_driver_580() {
    dnf install -y \
        xorg-x11-drv-nvidia-580xx akmod-nvidia-580xx install xorg-x11-drv-nvidia-580xx-cuda
}

install_nvidia_driver_470() {
    dnf install -y xorg-x11-drv-nvidia-470xx akmod-nvidia-470xx
    dnf install -y xorg-x11-drv-nvidia-470xx-cuda
}

install_cuda() {
    dnf config-manager addrepo \
        --from-repofile=https://developer.download.nvidia.com/compute/cuda/repos/fedora44/$(uname -m)/cuda-fedora44.repo
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

enable_flathub() {
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

gsettings_wrapper() {
    user="$(logname)"
    uid="$(id -u "$user")"
    bus_path="/run/user/$uid/bus"
    sudo -Hu "$user" env \
        "XDG_RUNTIME_DIR=/run/user/$uid" \
        "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus_path" \
        gsettings "$@"
}


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

make_gnome_usable() {
    dnf install -y gnome-tweaks gnome-extensions-app \
                gnome-shell-extension-appindicator \
                gnome-shell-extension-dash-to-dock
    enable_system_gnome_extension dash-to-dock@micxgx.gmail.com
    enable_system_gnome_extension appindicatorsupport@rgcjonas.gmail.com
    install_adw-gtk3
    gsettings_wrapper set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"   
}

install_nvidia_driver
install_cuda
make_gnome_usable
install_brave_origin
install_vscode
setup_rpmfusion
install_virt_manager
setup_zsh
