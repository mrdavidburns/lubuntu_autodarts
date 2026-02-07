# Copilot Instructions for lubuntu_autodarts

## Repository Overview

This repository provides automated setup scripts for configuring a Lubuntu installation as a dedicated AutoDarts system with custom branding and boot experience. The project consists of Bash shell scripts and Python utilities for system configuration.

## Code Style and Conventions

### Bash Scripts

- **Shebang**: Always use `#!/bin/bash` at the beginning of all Bash scripts
- **Comments**: Add descriptive comments for major sections and complex operations
- **Error Handling**: 
  - Use `|| sudo apt --fix-broken install -y` pattern for package installations
  - Check for file existence with `if [ -f "path" ]` before operations
  - Provide warning messages when optional files are missing
- **Paths**: 
  - Use `$(dirname "$0")` to reference files relative to the script location
  - Expand user home directory with `$HOME` or `~/`
  - Create directories with `mkdir -p` to avoid errors if they exist
- **Backups**: Create timestamped backups before modifying system files (e.g., `.bak.$(date +%F_%H-%M-%S)`)
- **Output**: Use `echo` statements to inform users of progress during script execution

### Python Scripts

- **Style**: Follow standard Python conventions
- **Imports**: Standard library imports at the top
- **ConfigParser**: Use `configparser.RawConfigParser()` for LXQt config files
- **Option Names**: Preserve case with `parser.optionxform = str`
- **Error Handling**: Wrap file operations in try-except blocks with informative error messages
- **Paths**: Use `os.path.expanduser()` for home directory expansion

## Project Structure

```
.
├── essentials.sh                    # Main orchestration script
├── setup_chrome_autostart.sh        # Chrome fullscreen autostart
├── setup_plymouth_theme.sh          # Plymouth theme installer
├── update_quick_launch.py           # LXQt panel quick launch updater
├── images/                          # Assets (logos, wallpapers)
└── plymouth_theme/                  # Plymouth theme files
```

## Key Technical Details

### Script Dependencies
- **essentials.sh** calls the other scripts in sequence
- Scripts should be runnable both standalone and from essentials.sh
- Use relative paths with `$(dirname "$0")` for portability

### Configuration Files Modified
- `~/.config/autostart/google-chrome-fullscreen.desktop` - Chrome autostart
- `~/.config/lxqt/panel.conf` - LXQt panel configuration
- `/etc/default/grub` - GRUB boot configuration
- `/etc/initramfs-tools/modules` - Early graphics modules

### System Operations
- Package installations require `sudo`
- GRUB updates require `sudo update-grub`
- Initramfs updates require `sudo update-initramfs -u`
- Plymouth theme changes need `update-alternatives` command

## Testing and Validation

This repository does not have automated tests. Manual testing involves:

1. **Script Execution**: Run scripts on a fresh Lubuntu installation
2. **File Checks**: Verify configuration files are created/modified correctly
3. **System Reboot**: Test Plymouth theme and autostart functionality
4. **Visual Validation**: Check wallpaper, panel icons, and boot screen

## Common Patterns

### File Copy with Existence Check
```bash
if [ -f "$(dirname "$0")/images/file.png" ]; then
    cp "$(dirname "$0")/images/file.png" ~/destination/
else
    echo "Warning: file.png not found."
fi
```

### Sed Configuration Updates
```bash
sed -i 's/old_value=false/new_value=true/g' config_file
sed -i "/^\[section\]/,/^\[/ s/^key=.*/key=new_value/" config_file
```

### Adding Items Without Duplicates
Check for existence before adding (see update_quick_launch.py pattern)

## Important Notes

- **Minimal Changes**: When modifying scripts, make surgical changes that preserve existing functionality
- **Backwards Compatibility**: Maintain compatibility with Lubuntu 22.04+
- **User Experience**: Provide clear echo messages during script execution
- **Safe Defaults**: Use fallback values when optional resources are missing
- **Documentation**: Update README.md when adding new features or changing behavior

## Security Considerations

- Never commit credentials or sensitive data
- Use HTTPS for downloads (wget/curl)
- Verify package sources (official repositories only)
- Create backups before modifying system files

## When Making Changes

1. **Understand the Context**: This is a personal setup repository for AutoDarts enthusiasts
2. **Test Locally**: Changes should be testable on a Lubuntu VM or physical machine
3. **Preserve User Data**: Never delete user files without warning
4. **Document Side Effects**: Note any system-level changes in comments
5. **Error Messages**: Provide helpful error messages that guide users to solutions
