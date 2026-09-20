# Fedora Toolkit

Fedora Toolkit is a script that aims to automate the usual post-installation steps for a Fedora 44 GNOME installation.

It provides a TUI with the option to apply my preferred setup all at once or install and configure individual features independently.

## How to run

Oneliner (don't get used to do this, but for convenience):

```sh
curl -fsSL https://raw.githubusercontent.com/polhdez/fedora-toolkit/refs/heads/main/fedora_toolkit.sh -o /tmp/fedora_toolkit.sh && sudo bash /tmp/fedora_toolkit.sh
```

Or clone the repository:
```sh
git clone https://github.com/polhdez/fedora-toolkit.git
cd fedora-toolkit
sudo bash fedora_toolkit.sh
```

## Features
Here is what is currently implemented:

### Additional repositories

- RPM Fusion
- Terra (from the Ultramarine project)
- Flathub, with the Bazaar app store added as well

### NVIDIA

- Automatically detects the GPU and installs the appropriate driver (open, 580, or 470)
- Sets up NVIDIA's CUDA Toolkit

### Applications from official repositories

- VS Code
- Brave

### Shell

- Sets up my lightweight `.zshrc` configuration with the Starship prompt

### System tweaks

- Enables parallel downloads in DNF to improve download speeds
- Create udev rule for optimal I/O scheduling

### Virt-manager

- Installs virt-manager and its dependencies
- Adds the user to the `libvirt` group

### GNOME tweaks

- Installs Dash to Dock and AppIndicator support
- Enables minimize and maximize window buttons
- Installs the `adw-gtk3` theme for GTK3 applications to provide a libadwaita-like appearance
