import configparser
import os

def update_quick_launch():
    path = os.path.expanduser("~/.config/lxqt/panel.conf")
    if os.path.exists(path):
        try:
            parser = configparser.RawConfigParser()
            parser.optionxform = str
            parser.read(path)
            
            # Find the quicklaunch section (usually [quicklaunch])
            ql_section = 'quicklaunch'
            if ql_section in parser:
                apps = []
                size = 0
                # Read existing size
                if 'apps\\size' in parser[ql_section]:
                    size = int(parser[ql_section]['apps\\size'])
                    
                # Read existing apps to avoid duplicates
                existing_paths = []
                for i in range(1, size + 1):
                    key = f"apps\\{i}\\desktop"
                    if key in parser[ql_section]:
                        existing_paths.append(parser[ql_section][key])
                
                # Apps to add
                new_apps = [
                    "/usr/share/applications/google-chrome.desktop",
                    "/usr/share/applications/qterminal.desktop"
                ]
                
                changed = False
                for app in new_apps:
                    if app not in existing_paths:
                        size += 1
                        parser[ql_section][f"apps\\{size}\\desktop"] = app
                        changed = True
                
                if changed:
                    parser[ql_section]['apps\\size'] = str(size)
                    with open(path, 'w') as f:
                        parser.write(f, space_around_delimiters=False)
                    print("Added items to Quick Launch.")
                else:
                    print("Quick Launch items already present.")
            else:
                print("Quick Launch section not found in panel config.")
                
        except Exception as e:
            print(f"Error updating Quick Launch: {e}")

if __name__ == "__main__":
    update_quick_launch()
