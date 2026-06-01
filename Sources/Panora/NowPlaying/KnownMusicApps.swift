// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Curated bundle IDs of players and browsers that may report now-playing info.
/// Used to seed the selective-scrobbling app list with apps actually installed.
let knownMusicApps: [(bundleID: String, name: String)] = [
    ("com.apple.Music", "Music"),
    ("com.spotify.client", "Spotify"),
    ("com.google.YouTube.Music", "YouTube Music"),
    ("com.tidal.desktop", "Tidal"),
    ("com.deezer.Deezer", "Deezer"),
    ("com.soundcloud.desktop", "SoundCloud"),
    ("com.swinsian.Swinsian", "Swinsian"),
    ("com.coppertino.Vox", "Vox"),
    ("com.audirvana.Audirvana-Origin", "Audirvana Origin"),
    ("com.audirvana.Audirvana-Studio", "Audirvana Studio"),
    ("com.plexamp.plexamp", "Plexamp"),
    ("com.plexapp.Plex", "Plex"),
    ("com.amazon.music", "Amazon Music"),
    ("com.qobuz.QobuzDesktop", "Qobuz"),
    ("com.roon.Roon", "Roon"),
    ("party.shadow.Cider", "Cider"),
    ("com.kaseb.Kaset", "Kaset"),
    ("org.videolan.vlc", "VLC"),
    ("com.colliderli.iina", "IINA"),
    ("com.pineplayer.PinePlayer", "Pine Player"),
    ("com.colibri.Colibri", "Colibri"),
    ("com.doppler.Doppler", "Doppler"),
    ("com.foobar2000.mac", "foobar2000"),
    ("org.clementine.player.Clementine", "Clementine"),
    ("org.strawberrymusicplayer.strawberry", "Strawberry"),
    ("com.elmediaplayer.Elmedia", "Elmedia Player"),
    ("com.justplay.JustPlay", "JustPlay"),
    ("com.musique.Musique", "Musique"),
    ("com.netease.CloudMusic", "网易云音乐"),
    ("com.tencent.QQMusic", "QQ音乐"),
    ("com.google.Chrome", "Chrome"),
    ("com.apple.Safari", "Safari"),
    ("org.mozilla.firefox", "Firefox"),
    ("com.brave.Browser", "Brave"),
    ("com.microsoft.edgemac", "Edge"),
    ("com.operasoftware.Opera", "Opera"),
    ("company.thebrowser.Browser", "Arc"),
    ("com.vivaldi.Vivaldi", "Vivaldi"),
]

/// Maps bundle IDs the adapter reports to the user-facing app they belong to
/// (e.g. Safari plays through a WebKit GPU helper process).
let mediaRemoteBundleMapping: [String: String] = [
    "com.apple.WebKit.GPU": "com.apple.Safari",
]
