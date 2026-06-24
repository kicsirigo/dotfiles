#!/usr/bin/env python3
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib
import subprocess
import os
import sys
import re
import signal
import threading
import time

# Set program name for Wayland app_id mapping
GLib.set_prgname("wifi-widget")
GLib.set_application_name("wifi-widget")

# --- SINGLE INSTANCE CHECK ---
# Clicking the Waybar widget again should close the open window.
def single_instance_check():
    pid_file = "/tmp/wifi-widget.pid"
    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                old_pid = int(f.read().strip())
            # Check if process is running
            os.kill(old_pid, 0)
            # Process is running, kill it and exit
            os.kill(old_pid, signal.SIGTERM)
            try:
                os.remove(pid_file)
            except Exception:
                pass
            sys.exit(0)
        except (OSError, ValueError):
            # Process is not running or invalid PID
            pass
            
    # Write current PID
    with open(pid_file, "w") as f:
        f.write(str(os.getpid()))

# Run check immediately
single_instance_check()

# --- THEME COLORS ---
THEME_COLORS = {
    "catppuccin_macchiato": {
        "base": "#24273a",
        "mantle": "#1e2030",
        "crust": "#181926",
        "text": "#cad3f5",
        "accent": "#8aadf4",
        "red": "#ed8796",
        "green": "#a6da95",
        "surface": "#363a4f",
        "border": "#494d64",
        "border_subtle": "rgba(73, 77, 100, 0.4)",
    },
    "catppuccin_latte": {
        "base": "#eff1f5",
        "mantle": "#e6e9ef",
        "crust": "#dce0e8",
        "text": "#4c4f69",
        "accent": "#1e66f5",
        "red": "#d20f39",
        "green": "#40a02b",
        "surface": "#ccd0da",
        "border": "#bcc0cc",
        "border_subtle": "rgba(188, 192, 204, 0.4)",
    },
    "nord": {
        "base": "#2e3440",
        "mantle": "#242933",
        "crust": "#1d212a",
        "text": "#d8dee9",
        "accent": "#88c0d0",
        "red": "#bf616a",
        "green": "#a3be8c",
        "surface": "#3b4252",
        "border": "#4c566a",
        "border_subtle": "rgba(76, 86, 106, 0.4)",
    }
}

# --- HELPERS ---
def run_in_thread(target, *args, **kwargs):
    thread = threading.Thread(target=target, args=args, kwargs=kwargs, daemon=True)
    thread.start()

def get_wifi_networks():
    try:
        res = subprocess.run(
            ["nmcli", "-t", "-f", "IN-USE,SSID,BSSID,SIGNAL,BARS,SECURITY", "device wifi list"],
            capture_output=True, text=True, check=True
        )
        lines = res.stdout.strip().split("\n")
        networks = []
        seen_ssids = set()
        
        for line in lines:
            if not line:
                continue
            parts = re.split(r'(?<!\\):', line)
            if len(parts) >= 6:
                in_use = parts[0].strip() == "*"
                ssid = parts[1].replace("\\:", ":").strip()
                bssid = parts[2].replace("\\:", ":").strip()
                signal = int(parts[3]) if parts[3].isdigit() else 0
                bars = parts[4].strip()
                security = parts[5].strip()
                
                if not ssid:
                    continue
                
                # Deduplicate SSIDs, keeping the strongest or connected one
                if ssid in seen_ssids:
                    for net in networks:
                        if net["ssid"] == ssid:
                            if in_use or (not net["in_use"] and signal > net["signal"]):
                                net["bssid"] = bssid
                                net["signal"] = signal
                                net["bars"] = bars
                                net["in_use"] = in_use
                                net["security"] = security
                    continue
                
                seen_ssids.add(ssid)
                networks.append({
                    "in_use": in_use,
                    "ssid": ssid,
                    "bssid": bssid,
                    "signal": signal,
                    "bars": bars,
                    "security": security
                })
        
        networks.sort(key=lambda x: (not x["in_use"], -x["signal"]))
        return networks
    except Exception as e:
        print("Error getting wifi list:", e)
        return []

# --- WIDGET WINDOW ---
class WifiWidget(Gtk.Window):
    def __init__(self):
        Gtk.Window.__init__(self)
        self.set_title("Wi-Fi Connections")
        self.set_wmclass("wifi-widget", "wifi-widget")
        self.set_role("wifi-widget")
        self.set_default_size(360, 450)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Load theme
        self.theme = self.get_current_theme()
        self.apply_css(self.theme)
        
        # Close events with a grace period to prevent immediate closing before cursor enters
        self.focus_close_enabled = False
        self.connect("focus-out-event", self.on_focus_out)
        self.connect("key-press-event", self.on_key_press)
        GLib.timeout_add(500, self.enable_focus_close)
        
        # States
        self.wifi_enabled = False
        self.bt_enabled = False
        self.airplane_mode = False
        
        # Layout container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(main_box)
        
        # 1. Header
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        header_box.get_style_context().add_class("header")
        main_box.pack_start(header_box, False, False, 0)
        
        title_lbl = Gtk.Label()
        title_lbl.set_markup("<b>Quick Settings</b>")
        title_lbl.get_style_context().add_class("header-title")
        header_box.pack_start(title_lbl, False, False, 0)
        
        self.spinner = Gtk.Spinner()
        self.spinner.set_visible(False)
        header_box.pack_end(self.spinner, False, False, 8)
        
        refresh_btn = Gtk.Button(label="󰑐")
        refresh_btn.get_style_context().add_class("header-btn")
        refresh_btn.connect("clicked", lambda b: self.refresh_list())
        header_box.pack_end(refresh_btn, False, False, 0)
        
        # 2. Toggle buttons grid
        grid = Gtk.Grid()
        grid.get_style_context().add_class("quick-settings")
        grid.set_column_spacing(12)
        grid.set_row_spacing(12)
        grid.set_column_homogeneous(True)
        main_box.pack_start(grid, False, False, 0)
        
        # Wi-Fi Button
        self.wifi_btn = Gtk.Button()
        self.wifi_btn.get_style_context().add_class("tile-btn")
        self.wifi_btn.connect("clicked", self.on_wifi_toggle_clicked)
        grid.attach(self.wifi_btn, 0, 0, 1, 1)
        
        wifi_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.wifi_btn.add(wifi_box)
        
        self.wifi_icon = Gtk.Label(label="󰤨")
        self.wifi_icon.get_style_context().add_class("tile-icon")
        wifi_box.pack_start(self.wifi_icon, False, False, 0)
        
        wifi_lbl = Gtk.Label(label="Wi-Fi")
        wifi_lbl.get_style_context().add_class("tile-title")
        wifi_box.pack_start(wifi_lbl, False, False, 0)
        
        self.wifi_sub = Gtk.Label(label="Off")
        self.wifi_sub.get_style_context().add_class("tile-sub")
        wifi_box.pack_start(self.wifi_sub, False, False, 0)
        
        # Airplane Mode Button
        self.airplane_btn = Gtk.Button()
        self.airplane_btn.get_style_context().add_class("tile-btn")
        self.airplane_btn.connect("clicked", self.on_airplane_toggle_clicked)
        grid.attach(self.airplane_btn, 1, 0, 1, 1)
        
        airplane_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.airplane_btn.add(airplane_box)
        
        airplane_icon = Gtk.Label(label="󰀝")
        airplane_icon.get_style_context().add_class("tile-icon")
        airplane_box.pack_start(airplane_icon, False, False, 0)
        
        airplane_lbl = Gtk.Label(label="Airplane Mode")
        airplane_lbl.get_style_context().add_class("tile-title")
        airplane_box.pack_start(airplane_lbl, False, False, 0)
        
        self.airplane_sub = Gtk.Label(label="Off")
        self.airplane_sub.get_style_context().add_class("tile-sub")
        airplane_box.pack_start(self.airplane_sub, False, False, 0)
        
        # 3. Section separator & Title
        section_lbl = Gtk.Label(label="Available networks")
        section_lbl.get_style_context().add_class("section-title")
        section_lbl.set_alignment(0, 0.5)
        main_box.pack_start(section_lbl, False, False, 0)
        
        # 4. Scrollable wifi list
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        main_box.pack_start(scroll, True, True, 0)
        
        self.list_box = Gtk.ListBox()
        self.list_box.get_style_context().add_class("network-list")
        self.list_box.connect("row-activated", self.on_row_activated)
        scroll.add(self.list_box)
        
        # Initial status check
        self.check_status()
        self.show_all()
        
        # Align position to cursor (try multiple times as the window maps)
        self.position_attempts = 0
        GLib.timeout_add(50, self.position_window)

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        return False

    def enable_focus_close(self):
        self.focus_close_enabled = True
        return False

    def on_focus_out(self, widget, event):
        if self.focus_close_enabled:
            Gtk.main_quit()
        return False

    def get_current_theme(self):
        state_file = os.path.expanduser("~/.config/themes/theme_switcher/current_theme")
        if os.path.exists(state_file):
            try:
                with open(state_file, "r") as f:
                    theme = f.read().strip()
                    if theme in THEME_COLORS:
                        return theme
            except Exception:
                pass
        return "catppuccin_macchiato"

    def apply_css(self, theme_name):
        colors = THEME_COLORS[theme_name]
        css = f"""
        window {{
            background-color: {colors['base']};
            color: {colors['text']};
            border: 1px solid {colors['border']};
            border-radius: 12px;
        }}
        
        scrollbar, scrollbar button, scrollbar slider {{
            background: transparent;
            border: none;
        }}
        scrollbar.vertical slider {{
            background-color: {colors['surface']};
            border-radius: 4px;
            min-width: 6px;
        }}
        scrollbar.vertical slider:hover {{
            background-color: {colors['border']};
        }}
        
        .header {{
            background-color: {colors['mantle']};
            border-bottom: 1px solid {colors['border']};
            padding: 12px 14px;
            border-radius: 12px 12px 0 0;
        }}
        .header-title {{
            font-family: 'CaskaydiaCove Nerd Font', sans-serif;
            font-size: 15px;
            color: {colors['text']};
        }}
        .header-btn {{
            background: transparent;
            border: none;
            color: {colors['text']};
            padding: 5px;
            border-radius: 6px;
            font-size: 16px;
        }}
        .header-btn:hover {{
            background-color: {colors['surface']};
        }}
        
        .quick-settings {{
            padding: 12px 14px;
            background-color: {colors['base']};
        }}
        .tile-btn {{
            background-color: {colors['surface']};
            color: {colors['text']};
            border: 1px solid {colors['border']};
            border-radius: 10px;
            padding: 12px;
            font-family: 'CaskaydiaCove Nerd Font', sans-serif;
        }}
        .tile-btn:hover {{
            background-color: {colors['border']};
        }}
        .tile-btn.active {{
            background-color: {colors['accent']};
            color: {colors['base']};
            border-color: {colors['accent']};
        }}
        .tile-btn.active:hover {{
            background-color: {colors['accent']};
            opacity: 0.9;
        }}
        .tile-icon {{
            font-size: 20px;
            margin-bottom: 4px;
        }}
        .tile-title {{
            font-size: 12px;
            font-weight: bold;
        }}
        .tile-sub {{
            font-size: 10px;
            opacity: 0.7;
        }}
        
        .section-title {{
            font-family: 'CaskaydiaCove Nerd Font', sans-serif;
            font-size: 12px;
            font-weight: bold;
            color: {colors['text']};
            opacity: 0.6;
            padding: 8px 14px 4px 14px;
        }}
        
        .network-list {{
            background-color: {colors['base']};
            border-radius: 0 0 12px 12px;
        }}
        .network-row-container {{
            background-color: transparent;
            border: none;
            padding: 2px 6px;
        }}
        .network-row-container:hover {{
            background-color: {colors['mantle']};
            border-radius: 8px;
        }}
        .network-row-container.connected {{
            background-color: {colors['mantle']};
            border-radius: 8px;
        }}
        .network-row-header {{
            padding: 10px 8px;
        }}
        .network-signal-icon {{
            font-size: 16px;
            color: {colors['accent']};
        }}
        .network-name {{
            font-family: 'CaskaydiaCove Nerd Font', sans-serif;
            font-size: 13px;
            color: {colors['text']};
        }}
        .network-lock-icon {{
            font-size: 12px;
            opacity: 0.6;
        }}
        .network-status-connected {{
            font-size: 11px;
            color: {colors['green']};
            font-weight: bold;
        }}
        .network-chevron {{
            font-size: 12px;
            opacity: 0.6;
        }}
        
        .connect-panel {{
            padding: 10px;
            background-color: {colors['crust']};
            border-radius: 8px;
            margin: 0 8px 8px 8px;
            border: 1px solid {colors['border']};
        }}
        .password-entry {{
            background-color: {colors['base']};
            border: 1px solid {colors['border']};
            border-radius: 6px;
            padding: 6px;
            color: {colors['text']};
            font-size: 12px;
        }}
        .password-entry:focus {{
            border-color: {colors['accent']};
        }}
        
        .action-btn {{
            border-radius: 6px;
            padding: 6px 12px;
            font-size: 12px;
            font-weight: bold;
            font-family: 'CaskaydiaCove Nerd Font', sans-serif;
        }}
        .action-btn.primary {{
            background-color: {colors['accent']};
            color: {colors['base']};
            border: none;
        }}
        .action-btn.primary:hover {{
            opacity: 0.9;
        }}
        .action-btn.secondary {{
            background: transparent;
            border: 1px solid {colors['border']};
            color: {colors['text']};
        }}
        .action-btn.secondary:hover {{
            background-color: {colors['surface']};
        }}
        
        .placeholder-label {{
            font-family: 'CaskaydiaCove Nerd Font', sans-serif;
            font-size: 13px;
            color: {colors['text']};
            opacity: 0.6;
            padding: 40px 20px;
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def position_window(self):
        self.position_attempts += 1
        try:
            res = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True)
            cursor_x, cursor_y = map(int, res.stdout.strip().split(","))
        except Exception:
            cursor_x, cursor_y = 1200, 32
            
        width = 360
        # Align widget's left edge to cursor position, offset slightly to center
        x = cursor_x - 60
        if x + width > 1590:
            x = 1590 - width
        if x < 10:
            x = 10
        y = 38 # Align just under Waybar (height is 32px + 6px gap)
        
        subprocess.run(["hyprctl", "dispatch", "movewindowpixel", f"exact {x} {y},class:wifi-widget"])
        
        # Repeat up to 10 times to catch the window mapping
        if self.position_attempts < 10:
            return True
        return False

    def check_status(self):
        # 1. Check Wi-Fi state
        try:
            res = subprocess.run(["nmcli", "radio", "wifi"], capture_output=True, text=True)
            wifi_enabled = res.stdout.strip() == "enabled"
        except Exception:
            wifi_enabled = False
            
        # 2. Check Bluetooth state
        try:
            res = subprocess.run(["bluetoothctl", "show"], capture_output=True, text=True)
            bt_enabled = "Powered: yes" in res.stdout
        except Exception:
            bt_enabled = False
            
        self.wifi_enabled = wifi_enabled
        self.bt_enabled = bt_enabled
        
        # Airplane mode is active if both are disabled
        self.airplane_mode = not wifi_enabled and not bt_enabled
        
        self.update_ui_states()

    def update_ui_states(self):
        # Update Wi-Fi tile
        if self.wifi_enabled:
            self.wifi_btn.get_style_context().add_class("active")
            self.wifi_icon.set_text("󰤨")
            active_ssid = self.get_active_ssid()
            if active_ssid:
                self.wifi_sub.set_text(active_ssid)
            else:
                self.wifi_sub.set_text("Available")
        else:
            self.wifi_btn.get_style_context().remove_class("active")
            self.wifi_icon.set_text("󰤮")
            self.wifi_sub.set_text("Off")
            
        # Update Airplane Mode tile
        if self.airplane_mode:
            self.airplane_btn.get_style_context().add_class("active")
            self.airplane_sub.set_text("On")
        else:
            self.airplane_btn.get_style_context().remove_class("active")
            self.airplane_sub.set_text("Off")
            
        self.refresh_list()

    def get_active_ssid(self):
        try:
            res = subprocess.run(
                ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"],
                capture_output=True, text=True
            )
            for line in res.stdout.strip().split("\n"):
                if line.startswith("yes:"):
                    return line.split(":")[1].strip()
        except Exception:
            pass
        return None

    def refresh_list(self):
        for child in self.list_box.get_children():
            self.list_box.remove(child)
            
        if self.airplane_mode:
            lbl = Gtk.Label(label="Airplane mode is on\nTurn it off to see networks")
            lbl.set_justify(Gtk.Justification.CENTER)
            lbl.get_style_context().add_class("placeholder-label")
            self.list_box.add(lbl)
            self.list_box.show_all()
        elif not self.wifi_enabled:
            lbl = Gtk.Label(label="Wi-Fi is turned off\nTurn it on to see networks")
            lbl.set_justify(Gtk.Justification.CENTER)
            lbl.get_style_context().add_class("placeholder-label")
            self.list_box.add(lbl)
            self.list_box.show_all()
        else:
            self.spinner.start()
            self.spinner.set_visible(True)
            
            lbl = Gtk.Label(label="Scanning for networks...")
            lbl.get_style_context().add_class("placeholder-label")
            self.list_box.add(lbl)
            self.list_box.show_all()
            
            def scan_task():
                networks = get_wifi_networks()
                GLib.idle_add(self.populate_networks, networks)
                
            run_in_thread(scan_task)

    def populate_networks(self, networks):
        self.spinner.stop()
        self.spinner.set_visible(False)
        
        for child in self.list_box.get_children():
            self.list_box.remove(child)
            
        if not networks:
            lbl = Gtk.Label(label="No networks found")
            lbl.get_style_context().add_class("placeholder-label")
            self.list_box.add(lbl)
            self.list_box.show_all()
            return
            
        for net in networks:
            row = self.create_network_row(net)
            self.list_box.add(row)
            
        self.list_box.show_all()

    def get_signal_icon(self, signal):
        if signal >= 80: return "󰤨"
        elif signal >= 60: return "󰤥"
        elif signal >= 40: return "󰤢"
        elif signal >= 20: return "󰤟"
        return "󰤯"

    def create_network_row(self, net):
        row = Gtk.ListBoxRow()
        row.get_style_context().add_class("network-row-container")
        
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        row.add(main_box)
        
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header_box.get_style_context().add_class("network-row-header")
        main_box.pack_start(header_box, True, True, 0)
        
        sig_icon = Gtk.Label(label=self.get_signal_icon(net["signal"]))
        sig_icon.get_style_context().add_class("network-signal-icon")
        header_box.pack_start(sig_icon, False, False, 0)
        
        name_lbl = Gtk.Label()
        name_lbl.set_markup(f"<b>{net['ssid']}</b>")
        name_lbl.set_alignment(0, 0.5)
        name_lbl.get_style_context().add_class("network-name")
        header_box.pack_start(name_lbl, True, True, 0)
        
        icons_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        header_box.pack_end(icons_box, False, False, 0)
        
        is_secure = net["security"] and "OPN" not in net["security"] and net["security"] != "--"
        if is_secure:
            lock_lbl = Gtk.Label(label="")
            lock_lbl.get_style_context().add_class("network-lock-icon")
            icons_box.pack_start(lock_lbl, False, False, 0)
            
        if net["in_use"]:
            status_lbl = Gtk.Label(label="Connected")
            status_lbl.get_style_context().add_class("network-status-connected")
            icons_box.pack_start(status_lbl, False, False, 0)
            row.get_style_context().add_class("connected")
            
        chevron = Gtk.Label(label="")
        chevron.get_style_context().add_class("network-chevron")
        icons_box.pack_start(chevron, False, False, 0)
        
        # Expandable panel
        details_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        details_box.get_style_context().add_class("connect-panel")
        details_box.set_no_show_all(True)
        details_box.set_visible(False)
        main_box.pack_start(details_box, False, False, 0)
        
        status_lbl = Gtk.Label(label="")
        status_lbl.set_alignment(0, 0.5)
        status_lbl.set_no_show_all(True)
        status_lbl.set_visible(False)
        details_box.pack_start(status_lbl, False, False, 0)
        
        if net["in_use"]:
            disconnect_btn = Gtk.Button(label="Disconnect")
            disconnect_btn.get_style_context().add_class("action-btn")
            disconnect_btn.get_style_context().add_class("secondary")
            
            def on_disconnect_clicked(btn):
                btn.set_sensitive(False)
                status_lbl.set_text("Disconnecting...")
                status_lbl.set_visible(True)
                status_lbl.show()
                
                def disconnect_task():
                    res = subprocess.run(["nmcli", "device", "disconnect", "wlan0"], capture_output=True)
                    GLib.idle_add(self.check_status)
                    
                run_in_thread(disconnect_task)
                
            disconnect_btn.connect("clicked", on_disconnect_clicked)
            details_box.pack_start(disconnect_btn, False, False, 0)
        else:
            entry_pass = None
            if is_secure:
                entry_pass = Gtk.Entry()
                entry_pass.set_visibility(False)
                entry_pass.set_placeholder_text("Enter network security key")
                entry_pass.get_style_context().add_class("password-entry")
                
                # Setup password visibility toggle
                entry_pass.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, "eye-open-negative-filled-symbolic")
                def on_icon_press(entry, icon_pos, event):
                    vis = entry.get_visibility()
                    entry.set_visibility(not vis)
                    icon_name = "eye-close-symbolic" if vis else "eye-open-negative-filled-symbolic"
                    entry.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, icon_name)
                entry_pass.connect("icon-press", on_icon_press)
                details_box.pack_start(entry_pass, False, False, 0)
                
            btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            details_box.pack_start(btn_box, False, False, 0)
            
            cancel_btn = Gtk.Button(label="Cancel")
            cancel_btn.get_style_context().add_class("action-btn")
            cancel_btn.get_style_context().add_class("secondary")
            btn_box.pack_start(cancel_btn, True, True, 0)
            
            connect_btn = Gtk.Button(label="Connect")
            connect_btn.get_style_context().add_class("action-btn")
            connect_btn.get_style_context().add_class("primary")
            btn_box.pack_start(connect_btn, True, True, 0)
            
            cancel_btn.connect("clicked", lambda b: self.collapse_row(row, details_box, chevron))
            
            # Connect action
            def on_connect_clicked(btn, entry=entry_pass):
                connect_btn.set_sensitive(False)
                cancel_btn.set_sensitive(False)
                if entry:
                    entry.set_sensitive(False)
                    
                status_lbl.set_text("Connecting...")
                status_lbl.set_visible(True)
                status_lbl.show()
                
                password = entry.get_text() if entry else None
                
                def connect_task():
                    cmd = ["nmcli", "device", "wifi", "connect", net["ssid"]]
                    if password:
                        cmd.extend(["password", password])
                    res = subprocess.run(cmd, capture_output=True, text=True)
                    success = res.returncode == 0
                    err = res.stderr.strip() or res.stdout.strip()
                    GLib.idle_add(self.on_connect_done, success, err, row, connect_btn, cancel_btn, entry, status_lbl)
                    
                run_in_thread(connect_task)
                
            connect_btn.connect("clicked", on_connect_clicked)
            if entry_pass:
                entry_pass.connect("activate", lambda e: on_connect_clicked(connect_btn))
                
        row.details_box = details_box
        row.chevron = chevron
        row.ssid = net["ssid"]
        return row

    def on_row_activated(self, listbox, row):
        if not hasattr(row, "details_box"):
            return
            
        is_visible = row.details_box.get_visible()
        
        # Collapse others
        for other in listbox.get_children():
            if other != row and hasattr(other, "details_box"):
                self.collapse_row(other, other.details_box, other.chevron)
                
        # Toggle current
        if is_visible:
            self.collapse_row(row, row.details_box, row.chevron)
        else:
            self.expand_row(row, row.details_box, row.chevron)

    def expand_row(self, row, details_box, chevron):
        details_box.set_visible(True)
        details_box.show_all()
        chevron.set_text("")
        
        # Focus on entry if secure
        for child in details_box.get_children():
            if isinstance(child, Gtk.Entry):
                child.grab_focus()
                break

    def collapse_row(self, row, details_box, chevron):
        details_box.set_visible(False)
        chevron.set_text("")

    def on_connect_done(self, success, err_msg, row, btn_conn, btn_cancel, entry_pass, status_lbl):
        if success:
            status_lbl.set_text("Connected successfully!")
            GLib.timeout_add(1000, self.reload_data)
        else:
            status_lbl.set_text(f"Failed to connect:\n{err_msg}")
            btn_conn.set_sensitive(True)
            btn_cancel.set_sensitive(True)
            if entry_pass:
                entry_pass.set_sensitive(True)
                entry_pass.grab_focus()

    def reload_data(self):
        self.check_status()
        return False

    def on_wifi_toggle_clicked(self, btn):
        btn.set_sensitive(False)
        new_state = not self.wifi_enabled
        
        def task():
            subprocess.run(["nmcli", "radio", "wifi", "on" if new_state else "off"])
            GLib.idle_add(self.on_toggle_done, btn)
            
        run_in_thread(task)

    def on_airplane_toggle_clicked(self, btn):
        btn.set_sensitive(False)
        new_state = not self.airplane_mode
        
        def task():
            if new_state:
                subprocess.run(["nmcli", "radio", "wifi", "off"])
                subprocess.run(["bluetoothctl", "power", "off"])
            else:
                subprocess.run(["nmcli", "radio", "wifi", "on"])
                subprocess.run(["bluetoothctl", "power", "on"])
            GLib.idle_add(self.on_toggle_done, btn)
            
        run_in_thread(task)

    def on_toggle_done(self, btn):
        btn.set_sensitive(True)
        self.check_status()

if __name__ == "__main__":
    def clean_exit(signum, frame):
        pid_file = "/tmp/wifi-widget.pid"
        try:
            os.remove(pid_file)
        except Exception:
            pass
        Gtk.main_quit()
        sys.exit(0)
        
    signal.signal(signal.SIGINT, clean_exit)
    signal.signal(signal.SIGTERM, clean_exit)
    
    app = WifiWidget()
    Gtk.main()
    
    pid_file = "/tmp/wifi-widget.pid"
    try:
        os.remove(pid_file)
    except Exception:
        pass
