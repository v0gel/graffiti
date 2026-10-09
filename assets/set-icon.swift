// Puts an icon on a file in Finder.

import AppKit
let a = CommandLine.arguments
guard a.count == 3, let img = NSImage(contentsOfFile: a[1]) else { print("usage: set-icon <icns> <file>"); exit(1) }
exit(NSWorkspace.shared.setIcon(img, forFile: a[2], options: []) ? 0 : 1)
