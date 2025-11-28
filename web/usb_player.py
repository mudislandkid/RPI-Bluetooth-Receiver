#!/usr/bin/env python3
"""
Local Music Player for RPI Bluetooth Audio Receiver
Plays music from local SD card storage
"""

import os
import time
import subprocess
import threading
import logging
from pathlib import Path
import json
import random

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('MusicPlayer')

# Supported audio formats
AUDIO_EXTENSIONS = {'.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg', '.opus', '.wma'}

# Local music directory
MUSIC_DIR = '/var/music'

# State file
STATE_FILE = '/var/lib/bluetooth-receiver/music_player_state.json'


class LocalMusicPlayer:
    """Manages local music playback from SD card"""

    def __init__(self):
        self.current_process = None
        self.playlist = []
        self.current_index = 0
        self.is_playing = False
        self.is_paused = False
        self.shuffle = False
        self.loop = True
        self.lock = threading.Lock()

        # Ensure state and music directories exist
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        os.makedirs(MUSIC_DIR, exist_ok=True)

        # Load music library on startup
        self.scan_music_library()

        logger.info(f"Local Music Player initialized with {len(self.playlist)} tracks")

    def scan_music_library(self):
        """Scan local music directory for audio files"""
        logger.info(f"Scanning {MUSIC_DIR} for music files...")
        music_files = []

        try:
            if not os.path.exists(MUSIC_DIR):
                logger.warning(f"Music directory {MUSIC_DIR} does not exist")
                return []

            for root, dirs, files in os.walk(MUSIC_DIR):
                for file in files:
                    # Skip hidden files and Mac resource forks
                    if file.startswith('.') or file.startswith('._'):
                        continue
                    if Path(file).suffix.lower() in AUDIO_EXTENSIONS:
                        full_path = os.path.join(root, file)
                        music_files.append(full_path)

            # Sort files alphabetically (case-insensitive)
            music_files.sort(key=lambda x: x.lower())

            self.playlist = music_files
            logger.info(f"Found {len(music_files)} music files")
            return music_files
        except Exception as e:
            logger.error(f"Error scanning music library: {e}")
            return []

    def toggle_shuffle(self):
        """Toggle shuffle mode"""
        with self.lock:
            self.shuffle = not self.shuffle
            if self.shuffle:
                # Save current track
                current_track = self.playlist[self.current_index] if self.current_index < len(self.playlist) else None
                # Shuffle playlist
                random.shuffle(self.playlist)
                # Find current track in shuffled playlist
                if current_track:
                    try:
                        self.current_index = self.playlist.index(current_track)
                    except ValueError:
                        self.current_index = 0
                logger.info("Shuffle enabled")
            else:
                # Restore alphabetical order
                self.scan_music_library()
                logger.info("Shuffle disabled")
            return self.shuffle

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

    def start_playback(self):
        """Start music playback"""
        with self.lock:
            if self.is_playing:
                logger.warning("Already playing")
                return False

            # Rescan music library
            self.scan_music_library()

            if not self.playlist:
                logger.warning("No music files found in library")
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
                'current_file': current_file,
                'current_index': self.current_index,
                'total_tracks': len(self.playlist),
                'shuffle': self.shuffle,
                'loop': self.loop
            }


# Global player instance
player = None


def main():
    """Main function"""
    global player

    player = LocalMusicPlayer()

    # Simple event loop to keep the service running
    logger.info("Local music player service started")
    logger.info(f"Music directory: {MUSIC_DIR}")
    logger.info(f"Loaded {len(player.playlist)} tracks")

    try:
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        logger.info("Shutting down...")
        if player.is_playing:
            player.stop_playback()


if __name__ == "__main__":
    main()
