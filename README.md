# Graffiti

A clipboard history for the Mac. Your last ten copies, on the wall, one key away.

I work with AI agents most of the day and kept losing stuff I'd copied a few minutes earlier.
So I made this. Hit ⌃⌘V wherever you're typing, pick a number, and it pastes.

It's free. Get it at [graffiti.kingdomofid.com](https://graffiti.kingdomofid.com).

## Keys

| Key | |
|---|---|
| ⌃⌘V | open the wall |
| 1 to 9, 0 | paste that clip (or click it) |
| ⇧ + number | paste it clean, as plain text with straight quotes and no `$ ` prompts |
| H | paste your held clip |
| ⇧H | hold the selected clip |
| ↑ ↓ return | pick and paste |
| esc | close it |

You get a preview of each clip, including pictures. If you copy text that has pictures in it, the
pictures come with it, and in a terminal they paste in as attachments after the text.

The held clip sits above the ten. Name it, and it stays there until you clear it. The pin on each
clip holds it too.

## Your stuff stays on your Mac

Clips live in memory while Graffiti is running and that's it. They don't go to a server or a
database. Passwords and keys show up as dots, aren't saved, and clear after a minute, and if you
paste one into a terminal or an AI app it asks you first.

During an update Graffiti writes the wall to your Mac for a moment so you don't lose it on the
restart, then deletes it.

Once a day it checks for an update. That check also counts installs and daily use as plain
totals with the version number. Nothing about you or your clips.

## Letting agents read it

Turn on Let Agents Read the Wall in the menu and anything on your Mac can read the wall from the
command line. It's off unless you turn it on.

```
graffiti          list the wall
graffiti 2 4      print clips 2 and 4 (H for the held clip)
```

Pictures come back as file paths. Secrets are never handed over.

## Settings

Most are in the spray can menu. A few more from Terminal:

```
defaults write com.superboss.graffiti hotkey "ctrl+cmd+v"
defaults write com.superboss.graffiti historySize -int 10
defaults write com.superboss.graffiti secretExpirySeconds -int 60
```

## Building

macOS 13 or later and the Xcode command line tools.

```
./build.sh                       app and dmg in dist/, for Apple silicon and Intel
swift assets/make-assets.swift   redraw icons and installer art from assets/art/
./release.sh "what changed"      build, sign and publish an update (bump VERSION in build.sh first)
./publish-site.sh                publish the download page
./stats.sh                       download and install counts
```

Updates are signed with my certificate and my update key, and Graffiti checks both before it
installs anything. If you build your own, you'll need your own of each. Put your public key in
`Updater.swift` and point the feed at your own site.

What changed in each version is in `CHANGELOG.md`.

## Credits

By M. Scott Vogel for [Kingdom of Id](https://kingdomofid.com). Designed in Brooklyn ❤️
The artwork is hand drawn.

Say hi: hello@kingdomofid.com

MIT license, see `LICENSE`.
