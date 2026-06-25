#!/usr/bin/env python3
import sys
import os
import subprocess
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib

class ThemeSwitcherApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.theme.switcher")

    def do_activate(self):
        self.window = Gtk.ApplicationWindow(application=self)
        self.window.set_title("Theme Switcher")
        self.window.set_default_size(800, 320)
        self.window.set_resizable(False)

        # Style provider for premium design aesthetic
        css_provider = Gtk.CssProvider()
        css_data = """
            window {
                background-color: #1e1e2e;
                color: #cdd6f4;
            }
            .main-container {
                padding: 24px;
            }
            .title-label {
                font-size: 22px;
                font-weight: bold;
                color: #f5c2e7;
                margin-bottom: 16px;
            }
            .theme-button {
                background-color: #313244;
                border: 2px solid #45475a;
                border-radius: 16px;
                padding: 12px;
                margin: 0px 8px;
                transition: background-color 0.25s ease, border-color 0.25s ease;
            }
            .theme-button:hover {
                background-color: #45475a;
                border-color: #f5c2e7;
            }
            .theme-label {
                font-size: 16px;
                font-weight: bold;
                color: #cdd6f4;
                margin-top: 12px;
            }
        """
        css_provider.load_from_data(css_data.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # Main layout
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_box.add_css_class("main-container")
        self.window.set_child(main_box)

        # Title
        title = Gtk.Label(label="Choose Your Theme")
        title.add_css_class("title-label")
        title.set_halign(Gtk.Align.CENTER)
        main_box.append(title)

        # Horizontal Box for cards
        cards_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        cards_box.set_halign(Gtk.Align.CENTER)
        main_box.append(cards_box)

        # Theme definitions pointing to respective wallpapers
        themes = [
            {
                "id": "catppuccin_macchiato",
                "name": "Catppuccin Macchiato",
                "image": os.path.expanduser("~/.config/themes/catppuccin_macchiato/misc-config/.config/wallpaper_arch.png")
            },
            {
                "id": "catppuccin_latte",
                "name": "Catppuccin Latte",
                "image": os.path.expanduser("~/.config/themes/catppuccin_latte/misc-config/.config/arch_pink.png")
            },
            {
                "id": "nord",
                "name": "Nord",
                "image": os.path.expanduser("~/.config/themes/nord/archlinux.png")
            }
        ]

        for theme in themes:
            btn = Gtk.Button()
            btn.add_css_class("theme-button")
            btn.connect("clicked", self.on_theme_selected, theme["id"])

            btn_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            
            # Wallpaper preview card render
            if os.path.exists(theme["image"]):
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(theme["image"], 210, 120, False)
                texture = Gdk.Texture.new_for_pixbuf(pixbuf)
                img = Gtk.Image.new_from_paintable(texture)
                btn_box.append(img)
            
            lbl = Gtk.Label(label=theme["name"])
            lbl.add_css_class("theme-label")
            btn_box.append(lbl)

            btn.set_child(btn_box)
            cards_box.append(btn)

        # Escape key listener to close menu
        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self.on_key_pressed)
        self.window.add_controller(key_controller)

        self.window.present()

    def on_theme_selected(self, button, theme_id):
        script_path = os.path.expanduser("~/.config/themes/theme_switcher/theme_switcher.sh")
        subprocess.run([script_path, theme_id])
        self.window.close()

    def on_key_pressed(self, controller, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.window.close()
            return True
        return False

if __name__ == "__main__":
    app = ThemeSwitcherApp()
    sys.exit(app.run(sys.argv))
