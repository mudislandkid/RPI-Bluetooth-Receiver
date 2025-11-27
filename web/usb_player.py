#!/usr/bin/env python3
"""
USB Music Player for RPI Bluetooth Audio Receiver
Automatically plays music from USB drives when inserted
"""

import os
import time
import subprocess
import threading
import logging
from pathlib import Path
import json

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('USBPlayer')

# Supported audio formats
AUDIO_EXTENSIONS = {'.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.opus', '.wma'}

# USB mount point
USB_MOUNT_BASE = '/media/usb'

# State file
STATE_FILE = '/var/lib/bluetooth-receiver/usb_player_state.json'


class USBMusicPlayer:
    """Manages USB music playback"""

    def __init__(self):
        self.current_process = None
        self.playlist = []
        self.current_index = 0
        self.is_playing = False
        self.is_paused = False
        self.usb_mounted = False
        self.current_usb_path = None
        self.loop = True
        self.lock = threading.Lock()

        # Ensure state directory exists
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)

        logger.info("USB Music Player initialized")

    def scan_usb_for_music(self, mount_point):
        """Scan USB drive for music files"""
        logger.info(f"Scanning {mount_point} for music files...")
        music_files = []

        try:
            for root, dirs, files in os.walk(mount_point):
                for file in files:
                    # Skip Mac resource fork files and hidden files
                    if file.startswith('._') or file.startswith('.'):
                        continue
                    if Path(file).suffix.lower() in AUDIO_EXTENSIONS:
                        full_path = os.path.join(root, file)
                        music_files.append(full_path)

            # Sort files alphabetically (case-insensitive)
            music_files.sort(key=lambda x: x.lower())

            logger.info(f"Found {len(music_files)} music files")
            return music_files
        except Exception as e:
            logger.error(f"Error scanning USB: {e}")
            return []

    def find_usb_mount(self):
        """Find mounted USB drive"""
        # Check common mount points
        mount_points = [
            '/media/usb',
            '/media/usb0',
            '/mnt/usb',
            '/media/pi',
        ]

        # Also check /media for any mounted drives
        if os.path.exists('/media'):
            try:
                for item in os.listdir('/media'):
                    full_path = os.path.join('/media', item)
                    if os.path.ismount(full_path):
                        mount_points.append(full_path)
            except:
                pass

        for mp in mount_points:
            if os.path.exists(mp) and os.path.ismount(mp):
                logger.info(f"Found USB mount at: {mp}")
                return mp

        return None

    def play_file(self, file_path):
        """Play a single audio file using mpg123 or similar"""
        try:
            logger.info(f"Playing: {os.path.basename(file_path)}")

            # Try mpg123 first (best for MP3), then ffplay (supports everything)
            # Use aplay with sox for format conversion if needed
            ext = Path(file_path).suffix.lower()

            if ext == '.mp3':
                # Use mpg123 for MP3 with ALSA output to hardware device
                cmd = ['mpg123', '-q', '-o', 'alsa', '-a', 'plughw:Headphones', file_path]
            else:
                # Use ffplay for other formats (from ffmpeg)
                # -nodisp: no display, -autoexit: exit when done, -loglevel quiet
                cmd = ['ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', file_path]

            self.current_process = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

            # Wait for playback to finish
            self.current_process.wait()

            return self.current_process.returncode == 0

        except FileNotFoundError:
            logger.error(f"Player not found. Install mpg123 or ffmpeg")
            return False
        except Exception as e:
            logger.error(f"Error playing file: {e}")
            return False

    def playback_loop(self):
        """Main playback loop"""
        while self.is_playing:
            with self.lock:
                if not self.playlist:
                    logger.info("Playlist empty, stopping")
                    self.is_playing = False
                    break

                if self.current_index >= len(self.playlist):
                    if self.loop:
                        logger.info("Reached end of playlist, looping...")
                        self.current_index = 0
                    else:
                        logger.info("Reached end of playlist, stopping")
                        self.is_playing = False
                        break

                current_file = self.playlist[self.current_index]

            # Play the file (outside lock to allow control operations)
            success = self.play_file(current_file)

            if success:
                with self.lock:
                    self.current_index += 1
            else:
                # Skip to next file on error
                logger.warning(f"Failed to play file, skipping")
                with self.lock:
                    self.current_index += 1

        logger.info("Playback loop ended")

    def start_playback(self, mount_point=None):
        """Start USB music playback"""
        with self.lock:
            if self.is_playing:
                logger.warning("Already playing")
                return False

            # Find USB mount if not provided
            if mount_point is None:
                mount_point = self.find_usb_mount()

            if not mount_point:
                logger.error("No USB drive found")
                return False

            self.current_usb_path = mount_point
            self.usb_mounted = True

            # Scan for music files
            self.playlist = self.scan_usb_for_music(mount_point)

            if not self.playlist:
                logger.warning("No music files found on USB")
                return False

            self.current_index = 0
            self.is_playing = True

            # Stop BlueALSA playback to avoid conflicts
            self.pause_bluetooth()

        # Start playback in background thread
        playback_thread = threading.Thread(target=self.playback_loop, daemon=True)
        playback_thread.start()

        logger.info(f"Started playback of {len(self.playlist)} files")
        return True

    def stop_playback(self):
        """Stop USB music playback"""
        with self.lock:
            self.is_playing = False

            if self.current_process:
                try:
                    self.current_process.terminate()
                    self.current_process.wait(timeout=2)
                except:
                    try:
                        self.current_process.kill()
                    except:
                        pass
                self.current_process = None

        # Resume Bluetooth
        self.resume_bluetooth()

        logger.info("Playback stopped")

    def next_track(self):
        """Skip to next track"""
        with self.lock:
            if not self.is_playing:
                return False

            if self.current_process:
                try:
                    self.current_process.terminate()
                except:
                    pass

        logger.info("Skipping to next track")
        return True

    def previous_track(self):
        """Go to previous track"""
        with self.lock:
            if not self.is_playing:
                return False

            self.current_index = max(0, self.current_index - 2)

            if self.current_process:
                try:
                    self.current_process.terminate()
                except:
                    pass

        logger.info("Going to previous track")
        return True

    def pause_bluetooth(self):
        """Pause Bluetooth audio playback"""
        try:
            subprocess.run(
                ['systemctl', 'stop', 'bluealsa-aplay'],
                timeout=5,
                check=False
            )
            logger.info("Paused Bluetooth playback")
        except Exception as e:
            logger.error(f"Error pausing Bluetooth: {e}")

    def resume_bluetooth(self):
        """Resume Bluetooth audio playback"""
        try:
            subprocess.run(
                ['systemctl', 'start', 'bluealsa-aplay'],
                timeout=5,
                check=False
            )
            logger.info("Resumed Bluetooth playback")
        except Exception as e:
            logger.error(f"Error resuming Bluetooth: {e}")

    def get_status(self):
        """Get current player status"""
        with self.lock:
            current_file = None
            if self.is_playing and self.current_index < len(self.playlist):
                current_file = os.path.basename(self.playlist[self.current_index])

            return {
                'is_playing': self.is_playing,
                'is_paused': self.is_paused,
                'usb_mounted': self.usb_mounted,
                'current_file': current_file,
                'current_index': self.current_index,
                'total_tracks': len(self.playlist),
                'loop': self.loop
            }


# Global player instance
player = None


def main():
    """Main function"""
    global player

    player = USBMusicPlayer()

    # Monitor for USB insertion
    logger.info("Monitoring for USB drives...")

    last_check_time = 0
    check_interval = 5  # Check every 5 seconds

    try:
        while True:
            current_time = time.time()

            if current_time - last_check_time >= check_interval:
                last_check_time = current_time

                usb_mount = player.find_usb_mount()

                if usb_mount and not player.is_playing:
                    logger.info(f"USB drive detected at {usb_mount}, starting playback")
                    player.start_playback(usb_mount)
                elif not usb_mount and player.is_playing:
                    logger.info("USB drive removed, stopping playback")
                    player.stop_playback()

            time.sleep(1)

    except KeyboardInterrupt:
        logger.info("Shutting down...")
        if player.is_playing:
            player.stop_playback()


if __name__ == "__main__":
    main()
