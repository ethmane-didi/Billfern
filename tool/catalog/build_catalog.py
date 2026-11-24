#!/usr/bin/env python3
"""Builds Billfern's subscription catalog and bundled brand logos.

Usage:
    python3 tool/catalog/build_catalog.py <path-to-extracted-simple-icons-package>

Download the Simple Icons npm package (CC0-1.0) and extract it, for example:
    curl -sSLo si.tgz https://registry.npmjs.org/simple-icons/-/simple-icons-<version>.tgz
    tar xzf si.tgz   # -> package/

Outputs (all committed to the repo):
    assets/data/subscription_catalog.json   catalog consumed by the app
    assets/logos/<id>.svg                   monochrome brand marks from Simple Icons
    docs/brand-logos.md                     per-logo source, guidelines and licence

SERVICES below is the single source of truth. A service gets a logo only when
Simple Icons ships one; brands that asked Simple Icons to remove their marks
(e.g. Microsoft, Adobe, Slack, Disney) intentionally fall back to initials in
the app. Never hand-draw or approximate a brand mark.

Brand colours come from Simple Icons when a logo exists; otherwise from the
brand's own published palette, or null when not verified (the app then uses
the category colour).
"""

import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "assets" / "data" / "subscription_catalog.json"
LOGO_DIR = ROOT / "assets" / "logos"
ATTRIBUTION_PATH = ROOT / "docs" / "brand-logos.md"

# (id, name, domain, category, simple-icons slug | None, fallback colour | None,
#  aliases, popular, regions)
SERVICES = [
    # Entertainment
    ("netflix", "Netflix", "netflix.com", "entertainment", "netflix", None, [], True, []),
    ("disney-plus", "Disney+", "disneyplus.com", "entertainment", None, "#113CCF", ["disney plus", "disney"], True, []),
    ("hbo-max", "HBO Max", "hbomax.com", "entertainment", "hbomax", None, ["max", "hbo"], True, []),
    ("prime-video", "Amazon Prime Video", "primevideo.com", "entertainment", None, "#00A8E1", ["prime video", "amazon prime", "prime"], True, []),
    ("apple-tv-plus", "Apple TV+", "tv.apple.com", "entertainment", "appletv", None, ["apple tv plus", "apple tv"], False, []),
    ("hulu", "Hulu", "hulu.com", "entertainment", None, "#1CE783", [], False, []),
    ("paramount-plus", "Paramount+", "paramountplus.com", "entertainment", "paramountplus", None, ["paramount plus", "paramount"], False, []),
    ("peacock", "Peacock", "peacocktv.com", "entertainment", None, "#000000", ["peacock tv"], False, []),
    ("youtube-premium", "YouTube Premium", "youtube.com", "entertainment", "youtube", None, ["youtube", "yt premium"], True, []),
    ("crunchyroll", "Crunchyroll", "crunchyroll.com", "entertainment", "crunchyroll", None, ["anime"], False, []),
    ("viaplay", "Viaplay", "viaplay.com", "entertainment", "viaplay", None, [], False, ["nordic"]),
    ("tv2-play", "TV 2 Play", "play.tv2.no", "entertainment", None, None, ["tv2", "tv 2", "tv2 play"], False, ["nordic"]),
    # Music
    ("spotify", "Spotify", "spotify.com", "music", "spotify", None, [], True, []),
    ("apple-music", "Apple Music", "music.apple.com", "music", "applemusic", None, ["itunes"], True, []),
    ("youtube-music", "YouTube Music", "music.youtube.com", "music", "youtubemusic", None, ["yt music"], False, []),
    ("tidal", "TIDAL", "tidal.com", "music", "tidal", None, [], False, []),
    ("deezer", "Deezer", "deezer.com", "music", "deezer", None, [], False, []),
    ("soundcloud", "SoundCloud", "soundcloud.com", "music", "soundcloud", None, ["soundcloud go"], False, []),
    # AI tools
    ("chatgpt", "ChatGPT", "chatgpt.com", "aiTools", None, "#10A37F", ["openai", "gpt", "chat gpt"], True, []),
    ("claude", "Claude", "claude.ai", "aiTools", "claude", None, ["anthropic"], True, []),
    ("gemini", "Google Gemini", "gemini.google.com", "aiTools", "googlegemini", None, ["gemini", "bard", "google ai"], False, []),
    ("perplexity", "Perplexity", "perplexity.ai", "aiTools", "perplexity", None, [], False, []),
    ("midjourney", "Midjourney", "midjourney.com", "aiTools", None, "#000000", ["mj"], False, []),
    ("cursor", "Cursor", "cursor.com", "aiTools", "cursor", None, ["cursor ai"], False, []),
    ("github-copilot", "GitHub Copilot", "github.com/features/copilot", "aiTools", "githubcopilot", None, ["copilot"], False, []),
    ("mistral", "Mistral Le Chat", "mistral.ai", "aiTools", "mistralai", None, ["le chat", "mistral"], False, []),
    # Design
    ("figma", "Figma", "figma.com", "design", "figma", None, [], True, []),
    ("canva", "Canva", "canva.com", "design", None, "#00C4CC", [], True, []),
    ("adobe-creative-cloud", "Adobe Creative Cloud", "adobe.com", "design", None, "#DA1F26", ["adobe", "creative cloud", "photoshop", "illustrator"], False, []),
    ("adobe-lightroom", "Adobe Lightroom", "lightroom.adobe.com", "design", None, "#31A8FF", ["lightroom", "adobe photography"], False, []),
    ("sketch", "Sketch", "sketch.com", "design", "sketch", None, [], False, []),
    ("framer", "Framer", "framer.com", "design", "framer", None, [], False, []),
    # Productivity
    ("notion", "Notion", "notion.so", "productivity", "notion", None, ["notion ai"], True, []),
    ("microsoft-365", "Microsoft 365", "microsoft.com/microsoft-365", "productivity", None, "#D83B01", ["office 365", "office", "word", "excel", "m365"], True, []),
    ("google-workspace", "Google Workspace", "workspace.google.com", "productivity", None, "#4285F4", ["g suite", "gsuite", "gmail business"], False, []),
    ("todoist", "Todoist", "todoist.com", "productivity", "todoist", None, [], False, []),
    ("grammarly", "Grammarly", "grammarly.com", "productivity", "grammarly", None, [], False, []),
    ("slack", "Slack", "slack.com", "productivity", None, "#4A154B", [], False, []),
    ("evernote", "Evernote", "evernote.com", "productivity", "evernote", None, [], False, []),
    ("obsidian", "Obsidian", "obsidian.md", "productivity", "obsidian", None, ["obsidian sync"], False, []),
    ("linear", "Linear", "linear.app", "productivity", "linear", None, [], False, []),
    ("asana", "Asana", "asana.com", "productivity", "asana", None, [], False, []),
    # Cloud storage
    ("icloud-plus", "iCloud+", "icloud.com", "cloudStorage", "icloud", None, ["icloud", "icloud plus", "apple storage"], True, []),
    ("google-one", "Google One", "one.google.com", "cloudStorage", None, "#4285F4", ["google drive storage", "google storage"], True, []),
    ("dropbox", "Dropbox", "dropbox.com", "cloudStorage", "dropbox", None, [], False, []),
    ("onedrive", "OneDrive", "onedrive.live.com", "cloudStorage", None, "#0078D4", ["microsoft onedrive"], False, []),
    ("proton-drive", "Proton Drive", "proton.me/drive", "cloudStorage", "protondrive", None, ["proton"], False, []),
    # Development
    ("github", "GitHub", "github.com", "development", "github", None, ["github pro", "github team"], False, []),
    ("vercel", "Vercel", "vercel.com", "development", "vercel", None, [], False, []),
    ("netlify", "Netlify", "netlify.com", "development", "netlify", None, [], False, []),
    ("supabase", "Supabase", "supabase.com", "development", "supabase", None, [], False, []),
    ("digitalocean", "DigitalOcean", "digitalocean.com", "development", "digitalocean", None, ["digital ocean", "do"], False, []),
    ("replit", "Replit", "replit.com", "development", "replit", None, ["repl.it"], False, []),
    ("jetbrains", "JetBrains", "jetbrains.com", "development", "jetbrains", None, ["intellij", "webstorm", "pycharm"], False, []),
    # Gaming
    ("xbox-game-pass", "Xbox Game Pass", "xbox.com", "gaming", None, "#107C10", ["game pass", "xbox"], True, []),
    ("playstation-plus", "PlayStation Plus", "playstation.com", "gaming", "playstation", None, ["ps plus", "psn", "playstation"], True, []),
    ("nintendo-switch-online", "Nintendo Switch Online", "nintendo.com", "gaming", None, "#E60012", ["nintendo", "switch online"], False, []),
    ("ea-play", "EA Play", "ea.com", "gaming", "ea", None, ["ea", "electronic arts"], False, []),
    ("ubisoft-plus", "Ubisoft+", "ubisoft.com", "gaming", "ubisoft", None, ["ubisoft plus", "ubisoft"], False, []),
    ("apple-arcade", "Apple Arcade", "apple.com/apple-arcade", "gaming", "applearcade", None, [], False, []),
    # Health & fitness
    ("strava", "Strava", "strava.com", "health", "strava", None, [], False, []),
    ("headspace", "Headspace", "headspace.com", "health", "headspace", None, ["meditation"], False, []),
    ("calm", "Calm", "calm.com", "health", None, None, ["meditation", "sleep"], False, []),
    ("myfitnesspal", "MyFitnessPal", "myfitnesspal.com", "health", None, None, ["mfp", "calorie counter"], False, []),
    ("fitbit-premium", "Fitbit Premium", "fitbit.com", "health", "fitbit", None, ["fitbit"], False, []),
    ("peloton", "Peloton", "onepeloton.com", "health", "peloton", None, [], False, []),
    ("sats", "SATS", "sats.no", "health", None, None, ["gym", "treningssenter"], False, ["nordic"]),
    # Learning
    ("duolingo", "Duolingo", "duolingo.com", "learning", "duolingo", None, ["duolingo super", "duolingo max"], True, []),
    ("coursera", "Coursera", "coursera.org", "learning", "coursera", None, ["coursera plus"], False, []),
    ("skillshare", "Skillshare", "skillshare.com", "learning", "skillshare", None, [], False, []),
    ("masterclass", "MasterClass", "masterclass.com", "learning", None, None, ["master class"], False, []),
    ("udemy", "Udemy", "udemy.com", "learning", "udemy", None, ["udemy personal plan"], False, []),
    # Security
    ("nordvpn", "NordVPN", "nordvpn.com", "security", "nordvpn", None, ["nord vpn", "nord"], False, []),
    ("expressvpn", "ExpressVPN", "expressvpn.com", "security", "expressvpn", None, ["express vpn"], False, []),
    ("proton-vpn", "Proton VPN", "protonvpn.com", "security", "protonvpn", None, ["protonvpn", "proton"], False, []),
    ("1password", "1Password", "1password.com", "security", "1password", None, ["one password", "password manager"], False, []),
    ("bitwarden", "Bitwarden", "bitwarden.com", "security", "bitwarden", None, ["password manager"], False, []),
    ("surfshark", "Surfshark", "surfshark.com", "security", "surfshark", None, [], False, []),
    # Books & audio
    ("storytel", "Storytel", "storytel.com", "reading", None, None, ["audiobooks", "lydbok"], False, ["nordic"]),
    ("audible", "Audible", "audible.com", "reading", "audible", None, ["audiobooks", "amazon audible"], False, []),
    ("podme", "Podme", "podme.com", "reading", None, None, ["podcasts", "podme premium"], False, ["nordic"]),
    ("substack", "Substack", "substack.com", "reading", "substack", None, ["newsletter"], False, []),
]


def load_simple_icons(package_dir: pathlib.Path):
    data = json.loads((package_dir / "data" / "simple-icons.json").read_text())
    icons = data if isinstance(data, list) else data["icons"]
    version = json.loads((package_dir / "package.json").read_text())["version"]
    return {icon["slug"]: icon for icon in icons if "slug" in icon}, version


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    package_dir = pathlib.Path(sys.argv[1]).resolve()
    icons, version = load_simple_icons(package_dir)

    ids = [service[0] for service in SERVICES]
    duplicates = {i for i in ids if ids.count(i) > 1}
    if duplicates:
        sys.exit(f"Duplicate catalog ids: {sorted(duplicates)}")

    LOGO_DIR.mkdir(parents=True, exist_ok=True)
    for stale in LOGO_DIR.glob("*.svg"):
        stale.unlink()

    entries, attributions, missing = [], [], []
    for (sid, name, domain, category, slug, colour, aliases, popular, regions) in SERVICES:
        logo = None
        if slug:
            icon = icons.get(slug)
            if icon is None:
                sys.exit(f"Simple Icons slug not found: {slug} ({sid})")
            shutil.copyfile(package_dir / "icons" / f"{slug}.svg", LOGO_DIR / f"{sid}.svg")
            logo = f"assets/logos/{sid}.svg"
            colour = f"#{icon['hex'].upper()}"
            licence = (icon.get("license") or {}).get("type", "CC0-1.0 (Simple Icons)")
            attributions.append(
                f"| `{sid}.svg` | {name} | `{slug}` | {icon.get('source', '')} | "
                f"{icon.get('guidelines', '—')} | {licence} |"
            )
        else:
            missing.append(name)
        entries.append({
            "id": sid,
            "name": name,
            "domain": domain,
            "category": category,
            "brandColor": colour,
            "logo": logo,
            "aliases": aliases,
            "popular": popular,
            "regions": regions,
        })

    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(json.dumps({"version": 1, "services": entries}, indent=2, ensure_ascii=False) + "\n")

    ATTRIBUTION_PATH.write_text(
        "# Brand logo attribution\n\n"
        "Generated by `tool/catalog/build_catalog.py`. Do not edit by hand.\n\n"
        f"Logos are monochrome brand marks from [Simple Icons](https://simpleicons.org/) "
        f"v{version} (`simple-icons` npm package). The Simple Icons project is released "
        "under CC0-1.0; individual icons may carry their own licence, listed below where "
        "Simple Icons provides one.\n\n"
        "All trademarks, logos and brand names are the property of their respective owners. "
        "Billfern uses them only to identify the service a user subscribes to (nominative use), "
        "does not imply endorsement, renders each mark unmodified apart from colour (its "
        "official brand colour, or monochrome), and preserves the original aspect ratio. "
        "Where a brand publishes usage guidelines they are linked below and must be "
        "respected.\n\n"
        f"Logos bundled: **{len(attributions)}** of {len(SERVICES)} catalog services.\n\n"
        "| File | Service | Simple Icons slug | Source | Brand guidelines | Licence |\n"
        "|---|---|---|---|---|---|\n"
        + "\n".join(attributions)
        + "\n\n## Services without a bundled logo\n\n"
        "Simple Icons does not ship these marks (several brands asked for removal). The app "
        "shows coloured initials instead. Only add a logo from the brand's official press or "
        "brand resources after checking its usage terms, and record the source here.\n\n"
        + "\n".join(f"- {name}" for name in missing)
        + "\n"
    )
    print(f"{len(entries)} services, {len(attributions)} logos, {len(missing)} without logo")


if __name__ == "__main__":
    main()
