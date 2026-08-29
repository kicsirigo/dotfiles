#!/usr/bin/env python3
import sys
import subprocess
import gi

gi.require_version('Gio', '2.0')
gi.require_version('GLib', '2.0')
from gi.repository import Gio, GLib

def send_notification(summary, body):
    try:
        subprocess.run(['notify-send', '-i', 'drive-removable-media', summary, body], check=False)
    except Exception:
        pass

def mount_volume(volume):
    root = volume.get_activation_root()
    uri = root.get_uri() if root else ''
    name = volume.get_name()
    
    if volume.can_mount() and uri.startswith('mtp:'):
        print(f"[MTP Automount] Attempting to mount: {name} ({uri})", flush=True)
        
        def on_mount_done(source, res, data):
            try:
                source.mount_finish(res)
                print(f"[MTP Automount] Successfully mounted: {name}", flush=True)
                send_notification('MTP Device Mounted', f'Device "{name}" is now mounted and ready.')
            except Exception as e:
                err_msg = str(e)
                if 'already mounted' in err_msg.lower():
                    print(f"[MTP Automount] Device {name} is already mounted.", flush=True)
                else:
                    print(f"[MTP Automount] Failed to mount {name}: {e}", flush=True)
                    send_notification('MTP Mount Failed', f'Could not mount "{name}": {e}')

        op = Gio.MountOperation.new()
        volume.mount(Gio.MountMountFlags.NONE, op, None, on_mount_done, None)

def on_volume_added(monitor, volume):
    print(f"[MTP Automount] New volume detected: {volume.get_name()}", flush=True)
    mount_volume(volume)

def main():
    print("[MTP Automount] Daemon starting...", flush=True)
    vm = Gio.VolumeMonitor.get()
    vm.connect('volume-added', on_volume_added)
    
    # Process any already plugged in volumes
    for volume in vm.get_volumes():
        mount_volume(volume)
        
    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        print("[MTP Automount] Daemon stopped.", flush=True)

if __name__ == '__main__':
    main()
