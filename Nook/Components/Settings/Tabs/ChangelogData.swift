// Licensed under GPL-3.0. See LICENSE.
// Generated from VEGA_CHANGELOG.md by scripts/gen-changelog.py. Do not edit.

let vegaChangelogMarkdown = #"""
# Vega changelog

What Vega changes on top of [Nook](https://github.com/nook-browser/Nook). Nook's own changes reach Vega when they are ported; they're in [CHANGELOG.md](CHANGELOG.md) and [Nook's releases](https://github.com/nook-browser/Nook/releases).

## Vega 1.8.11 (2026-11-25)

### New
- **Boost Focus:** in a site's Boost, Focus picks one part of the page and dims everything else, and keeps it for that site. (Automatic dark mode was already there as Dark page.)
- **Video speed:** the sidebar media controls have a speed button, 0.5× to 2×. Picture in Picture keeps the speed.
- **Open Vega at login:** Settings › General › Startup, through macOS Login Items.
- **Pause downloads:** a running download can be paused, resumed and cancelled from the downloads list. It continues where it stopped when the site allows it; otherwise it starts over in the same file.
- **Keep sites signed in:** with "Clear cookies, site data and history when Vega quits" on, Settings › Privacy lists sites that keep their cookies and data, so you stay signed in to them.
- **Extensions icon:** an animated cube in Settings, and still icons now match the brightness of the others.

### Privacy and security
Reviewed before release; one problem fixed.
- **Kept sites are your choice:** only the sites you add keep their data at quit; history is still cleared. A site keeps its whole domain's data, since that is where a sign-in lives (keeping mail.google.com keeps google.com's cookies).
- **Downloads resume in their own profile**, with that profile's cookies. A download from a private window can resume only while the window is open; after that it now says so instead of doing nothing (the fix).
- **Boost Focus** accepts only a plain selector, the same check as Zap, so a Boost file can't inject styles.
- No new network destinations, Keychain items or files beyond your own downloads.

## Vega 1.8.10 (2026-11-25)

### Changes
- **Settings › Extensions** in Vega's design: "From a File…" and "Chrome Web Store" under the title, a Profiles menu when profiles keep their own extensions, and each extension's row with its icon, version, a short description, an update or Safari-version badge, its switch and a round "…" menu (Settings…, Allow in Private Browsing, Update or Switch to the Safari version, Remove…).
- **One extension icon everywhere:** Vega's cube in the Settings sidebar, page headers, the address bar and new-space screens, instead of a mix of icons.

### Privacy and security
Reviewed before release.
- **Test builds can't touch your Keychain:** a copy of Vega built under another app id now keeps its own Keychain items for passwords, the sync key, the Google sign-in, AI keys, website logins and Bitwarden. Before, some of these were shared with the real app.
- No new network destinations or files.

## Vega 1.8.9 (2026-11-25)

### Fixes
- **Settings and extension data kept as before 1.8.8:** 1.8.8 read some settings under new names, so it could start extensions with empty storage and lose a few choices. 1.8.9 goes back to the names every earlier version used, so everything set before 1.8.8 is back. Choices made only in 1.8.8 may need to be set again.
- **Settings › Extensions** has Vega's own design again (the larger icons, the row menu), now with Settings…, Update and Switch to the Safari version in each row's menu and a confirmation before removing.
- The app's menus build with the Xcode used for releases.

### Privacy and security
Reviewed before release; nothing needed fixing.
- No new network destinations, Keychain items or files. Extension storage and settings are read from the same places 1.8.7 used.

## Vega 1.8.8 (2026-11-25)

### New
- **Extensions per profile:** in Settings › Profiles a profile can share its extensions and their data with the others or keep its own. Settings › Extensions shows one list per group of profiles.
- **Import lists show what extensions ask for** before anything installs, and the consent sheet names the files and sites an extension wants to reach.

### Fixes
- **Extension updates** that are cut short by a quit keep the previous version, and removing an extension also unpins it.
- **Large spaces:** extensions asking for your tabs no longer freeze Vega when a space has hundreds of them.
- **Back** on a tab opened from a link returns to the tab the link came from.
- **Translate** reads a page's language from all of its text, not just the first words.
- **Error page:** a page under the error page can no longer dismiss it or take key presses, in split view too.
- Chat tools can reach fixed-position buttons and fields on a page.
- A test build under another app id starts with its own empty data, so it can't touch your installed Vega's extensions or settings.

### Privacy and security
Reviewed before release; nothing needed fixing.
- **No new network destinations** and no new Keychain or file access: this release only changes how extensions are grouped and listed.
- **Profiles that keep their own extensions** also keep their own extension storage and web data, so an extension in one profile can't see another profile's.
- **Removing a profile's extension set** deletes its folder and its saved extension data.

## Vega 1.8.7 (2026-11-24)

### New
- **Look It Up:** in the Cmd-T command bar, Shift-Return (or the new Look It Up row under what you typed) searches DuckDuckGo, reads the top pages and writes one page answering your question, with booking cards for flights and hotels. It uses your AI provider, or Apple's on-device model when you have none. Turn it off in Settings › AI. (From Nook.)
- **Link hints:** press Option-F on any page and every link, button and field gets a letter; type the letter to click it. (From the satyasaibhushan Nook fork.)
- **Command bar:** open tabs that match what you type come first, and Return switches to the tab instead of opening the page again. With nothing typed, your open tabs are listed most recent first.
- **Auto-Play per site:** Allow All, Stop Media with Sound, or Never, in Site Permissions and the address bar's site panel.
- **Error page:** a page that can't load shows a clear page with Go Back and Try Again instead of a blank tab, in split view too.
- **Local devices:** a NAS or router reached by name (tower.local, nas.lan, router.home.arpa) can now be opened after accepting its own certificate, as addresses already could.

### Fixes
- **Cmd-click** on a link now always opens it in a new tab (Shift-Cmd-click brings it forward), including on sites that stop the click and on target=_blank links.
- **Closing a tab keeps the tabs opened from it.** The close button on a tab row used to close its children too; they now move up as normal tabs, as Cmd-W already did.
- **Sync between Macs:** a Mac whose Google sign-in had expired fell back to iCloud Drive without saying so, and stopped seeing your other Macs. Vega now notices the expired sign-in and asks you to sign in again, Settings says why the Vega Sync server failed, and the server is retried every minute. Google sign-ins also no longer expire after 7 days. **Sign in with Google again once on each Mac** (Settings › Account).
- **Address bar:** the selected address now shows a clear highlight.
- **YouTube:** with Shorts hidden, a Shorts link opens as the regular video.
- Sites with a bad certificate on their upgraded https address fall back to http instead of leaving the tab stuck; ad-block fixes from Nook (a rule for some sites no longer hides buttons everywhere, lists with Windows line endings, rules scoped to sites); Translate reads the whole page to detect its language; several speed fixes for background tabs, media and the sidebar.

### Privacy and security
Reviewed before release; one problem found and fixed.
- **Ad-block removals list:** the new list that can switch off a bad ad-block rule without an app update was fetched from Nook's repository, which would have let a third party weaken Vega's blocker. It is now fetched from Vega's own repository. It can only remove rules, and a bundled copy is used until it downloads.
- **New network destination:** Look It Up contacts DuckDuckGo with your query, and your AI provider with what it read, only when you press Shift-Return. Never in private windows.
- **Link hints** run in their own isolated script world: a page can't see, fake or trigger them.
- **Local-device certificates:** only names that can't be on the public internet (.local, .lan, .home.arpa, .internal, single-word names) get the accept prompt, and you decide each time. Public sites never do.
- **Google sign-in:** an expired sign-in is deleted from the Keychain rather than retried. Sync failures are logged with their reason only, no addresses or content.
- **Website:** Vega now has a home page and privacy policy at clarifyingchaos.github.io/vega-browser.
- Checked and unchanged: the assistant's new fill tool asks before acting like its other actions; Cmd-click reacts only to real clicks; no new permissions or entitlements.

## Vega 1.8.6 (2026-11-24)

### Fixes
- **Site icons now work the way Arc and Dia do it:** each page keeps the icon it declares, read from the loaded page itself. Pages on one site can have different icons (Google Docs and Sheets), and a site's own icon stands in for pages you haven't visited yet. Google no longer shows Google Meet's icon: an icon fetched for a page you had already left is never shown, a tab that moves to another site shows the globe until the new icon arrives, and a pinned tab keeps a redirect's icon (gmail.com to mail.google.com) only for a real redirect. History and link previews use the same rules, and history no longer takes an icon from a site a page redirected to. The old icon cache is cleared once, so icons that were wrong before are fetched again.
- **Icons that change while a page is open** (Gmail's unread count) are followed. The changing icon is shown, not saved, so an old count never comes back on your next visit.
- **Pop-ups you allow for a site now also work inside frames embedded in its pages** (a video player, a widget). Blocking is unchanged: with it on, those frames still can't open pop-ups.

### Privacy and security
Reviewed before release; four problems found and fixed.
- **Saved passwords no longer cross sites on shared hosting.** Vega now decides which addresses are one site with the Public Suffix List (bundled, the same list Safari and Chrome use), not a short hand-made list. A login saved on one github.io, vercel.app, netlify.app, pages.dev or blogspot site was offered, with its user names, on every other site under the same host. The password still needed Touch ID. If the list can't be read, every address counts as its own site.
- **A sign-out could be undone.** Vega keeps a copy of your sign-in cookies to put back ones the system loses while tabs sleep. For a second after a sign-out, or after you cleared website data, that copy could put the old sign-in back. It is now left alone while cookie changes are still being saved, and its folder is readable by you only.
- **Browser Control** (off by default): its access token is created readable by you only from the start, and checked in constant time.
- **System log:** the site name of every page the content blocker handled, addresses of tabs opened by extensions, a tab title, routing rules, and SponsorBlock and image hosts were written to the macOS log as readable text. They are now redacted.
- Icons: a changing icon is read from the page by Vega, never taken from a message the page sends, and a picture embedded in an icon is size-limited.
- Checked and unchanged: AI assistant tools still ask before acting and always ask before running code; saved-password filling still needs Touch ID, a secure page and the site you are on; downloads keep the quarantine flag; shared space files import web addresses only; password sync is still encrypted before it leaves your Mac.
- No new network destinations, permissions or entitlements.

## Vega 1.8.5 (2026-11-24)

### Fixes
- **Picture in Picture:** shrinking the floating video by one of its edges no longer squeezes it into a thin horizontal pill. The panel now keeps the video's own shape and a sensible minimum size, including after you pop it out from the sidebar's media bar.

### Privacy and security
Reviewed before release.
- Only the size and shape of the floating video panel changed. No new network destinations, files, permissions or entitlements, and nothing is read from or sent about the video.

## Vega 1.8.4 (2026-11-24)

### New
- **Spaces:** each space dot is tinted with its space's colour, and hovering one names the space after a fraction of a second instead of the slow system tooltip.
- **Pop-ups, per site.** Settings › Privacy keeps pop-up blocking on by default; Site Controls and Site Permissions now let you allow or block pop-ups for one site. Pop-ups a page opens without a click are still blocked; a site you allow is left alone.
- **Easel redesign:** page cards show a picture of the page, to-do cards, and cards move and resize with the right hand cursors.
- **Captures:** Capture Visible Area and Capture Full Page are kept in the Library's Media view, next to the screenshots macOS took.
- **Solid confirmations:** delete and discard questions are clear system alerts instead of see-through glass; Vega's own dialogs have an opaque card and a darker backdrop.
- **Resize cursors** on the window edges and on Picture in Picture.

### Fixes
- **Scroll-bar corner:** the dark, white or orange square where a vertical and a horizontal scroll bar meet is gone. The corner, the track and the layer behind the page now take the colour the page really paints, not the site's theme colour.
- **Links that did not open:** a site's own "leaving this site" page (Behance, for one) now opens the address it carries.
- **Wrong site icon:** Behance no longer shows Adobe's icon; an icon is kept only while the page is still on the site it came from.
- A round of fixes to captures, Picture in Picture, hover previews, drag and select, the accent colour, refresh and recovering your session.

### Privacy and security
Reviewed before release.
- **Pop-ups:** the per-site choice is saved on your Mac with your other site settings. It changes only whether a page may open a window; nothing is sent anywhere.
- **Captures** are saved in Vega's own folder on your Mac with the site's name in the file name, and copied to the clipboard. They are not kept from private windows: a private window now says so instead of saving.
- **Screenshots from macOS** now appear in the Library. Vega lists the screenshot folder, the Desktop and what Spotlight marks as a screenshot, only on your Mac, and shows them in the grid; it does not read their contents beyond a preview, upload them or send them to the assistant. macOS may ask once to let Vega see the Desktop.
- **Easel page pictures:** a card for a public https page makes one request to that page for its share picture, with no cookies and no sign-in, and never to a local name or a raw IP address. The picture is stored on your Mac.
- **Scroll-bar colour:** Vega reads one pixel of the page it is showing to colour the scroll bar. The pixel stays in the app; the page is only given a colour value.
- **Site icons:** an icon is no longer taken from a site the request was redirected to.
- **Sign-ins:** a session cookie that the system lost while your tabs slept is put back from Vega's saved copy, never over a newer one, and never in private windows.
- No new permissions or entitlements.

## Vega 1.8.3 (2026-11-19)

### New
- **A clearer "Save Password?" prompt in the sidebar.** It names the site and the user name in its own box, "Save Password" is the full-width main button, "Not Now" is a lighter full-width button you can actually see on the dark card, and "Never for This Website" is a quiet link under them instead of a third button squeezed into one row. The text is brighter and the spacing is roomier. "Update Password?" looks the same.

### Privacy and security
Reviewed before release.
- Only how the prompt looks changed. What it saves, where, and when it asks is the same: nothing is saved until you press Save Password, private windows never ask, and Never for This Website still remembers your choice for that site.
- No new network destinations, permissions or entitlements.
- The password itself is never shown in the prompt.

### Known
- The macOS "Passwords" pop-up can still appear over a login field. macOS draws it, and Vega has no setting that hides it; System Settings › General › AutoFill & Passwords can.

## Vega 1.8.2 (2026-11-19)

### New
- **Spaces settings, redesigned:** each space is a calm row with its icon and color, its tab count at the right and a quiet … menu (rename, change icon or color, move). A soft highlight follows the pointer, the badge gives feedback when pressed, and spaces slide into place when you reorder them (a plain fade if you use Reduce Motion).
- **AI settings, redesigned:** the assistant, on-device features, providers, models and generation settings are grouped into clear sections. Providers and models have a switch and a … menu instead of rows of buttons, and Chat Position is a menu that opens below its control.
- **Slimmer scroll bars everywhere:** the wide always-visible bar no longer takes a strip of the window; the slim one shows while you scroll.
- **Privacy Report and Task Manager** have more room, a taller title bar, and clearer section titles. The Task Manager drops its blank rows, and "1 sites" now reads "1 site".
- **History in the Library** folds a run of look-alike pages (same title and site, such as a sign-in redirect loop) into one row, "accounts.google.com · 10 pages". Removing it removes all of them.

### Fixes
- Release notes in Settings › Updates showed raw `>` and `**`; they now read properly. The beta and crash-report rows have room.
- Settings › Tweaks: SponsorBlock has its own header.
- **Sync passphrase dialog:** on a first-time setup, or a new sync server, it said Vega couldn't reach your sync folder. It now offers "Create Sync Passphrase", as intended.
- Quieter internals: missing imports, actor-isolation notices and dead error branches cleaned up.

### Privacy and security
Reviewed before release.
- No new network destinations, permissions or entitlements.
- Scroll bars: Vega now asks each of its own scroll views to use the slim style; web pages are not touched.
- History folding changes only what the list shows; nothing is deleted or sent anywhere unless you remove a row.
- The passphrase fix changes which message is shown. It does not change how passphrases, keys or passwords are stored or sent.

## Vega 1.8.1 (2026-11-19)

### New
- **Vega Sync server.** Sync now has its own server (Cloudflare) for near-instant changes between your Macs. It is the first place Vega tries.
- **Automatic sync.** Vega syncs through the Vega Sync server, then iCloud Drive, then your Google account, and moves to the next one if a place can't be reached. It tries the first again every few minutes. You can still pick one place in Settings › General › Sync.
- Moving to a new place carries your sync passphrase with it, so your other Macs open the sealed passwords and settings with the same passphrase.

### Privacy and security
Reviewed before release.
- The server stores only files sealed on your Mac with your sync passphrase, so it can't read them. It checks your Google sign-in against Google's public keys, keeps files per account, and stores no passwords or emails.
- Mac-to-server traffic is HTTPS only. There are no new permissions or entitlements.
- A Mac that still runs an older Vega keeps syncing through Google or iCloud; it won't see this Mac until it updates.

## Vega 1.8.0 (2026-11-19)

### New
- **Easels in the Library**, plus New Easel in the + menu, the sidebar's right-click menu, Window › View Easels… and the command palette.
- **Command palette commands.** Type a command's name, or `>` to list them all: Capture, Cast, Reader View, Task Manager, Privacy Report, Restore and other Macs' tabs.
- **Task Manager** (Window menu, ⌥⌘Esc): memory per tab, with Sleep and Sleep Background Tabs.
- **Privacy Report** (Privacy menu): trackers blocked per site and pages upgraded to HTTPS. "Warn before HTTP" is now named HTTPS-Only Mode.
- **Site Permissions** (Settings › Privacy): every site's camera, microphone, JavaScript, mobile site, picture-in-picture and ad blocking, editable and resettable.
- **Restore from Backup** (Settings › Spaces › Backups): the last 7 days of spaces, favorites, pinned tabs and folders.
- **Security Check** for all your passwords (leaked, reused, weak) and **verification codes** (TOTP) beside a login.
- **Shortcuts actions:** open a page, search, switch space, new easel, Task Manager.
- **Feature Tour** (Help menu), shown once after this update.
- **Opt-in crash reports** and a **beta update channel** (Settings › Updates), both off by default.
- **Spaces settings redesigned:** one badge per space with its icon and color, tab counts, and a profile picker only when you have more than one profile. Change a space's icon or color from its … menu.

### Fixes
- **Sync from iCloud Drive arrives in about 4 seconds**, and Google Drive is checked every 30 seconds with one small request.
- **Spaces, favorites and settings are now sealed in sync** with your sync passphrase, like passwords. A readable copy stays while a Mac with an older Vega is in the chain.
- A "Not Synced" banner in Passwords lists logins from older Vega versions that can't sync without a prompt, with a CSV re-import to fix them.
- A download stuck at "Pending" now fails after a minute.
- Site icons for The Toolbox and Freepik load on their own.
- Clear-on-quit says plainly what it does and that Sync carries it to your other Macs.
- Extensions: the window's tab list is built once per turn instead of once per extension per tab change.
- Sync's local work runs off the main thread.

### Privacy and security
Reviewed before release.
- Spaces, favorites and settings are end-to-end sealed in sync with the same key as passwords (AES-GCM). Older Macs still get a readable copy until they update.
- Privacy Report counts are host names and numbers kept only on this Mac, never from private windows, capped at 400 sites.
- Verification-code secrets live in this Mac's Keychain beside the password. They're shown or copied only after Touch ID, aren't synced, and are deleted with the login.
- The Security Check reads passwords only after Touch ID, off the main thread. The leak check sends only the first 5 characters of each password's hash.
- Crash reports are off by default; nothing is sent on its own, and home-folder paths are shortened to `~`.
- Shortcuts actions skip the vega:// setting's gate (a shortcut is your own); vega:// links from other apps still need it.
- No new entitlements. The only new network destination is a sync server you must set up yourself; nothing talks to it by default.

## Vega 1.7.14 (2026-11-19)

### Fixes
- **Vega no longer freezes for a moment every 20 seconds.** Password sync read your Keychain on the same thread that draws the window, one login at a time, which held the window for up to a second and a half. It now runs in the background and finds each login directly.
- **Sync sends and takes only what changed.** While nothing changes, Vega checks less and less often (every 20 seconds at first, then up to every 5 minutes) instead of running a full round every 20 seconds. A change you make is sent a few seconds later, and Vega checks right away when you switch back to it or press Sync Now.
- **Google Drive sync makes far fewer requests.** A round where nothing changed used to make about 30; it now makes one. A file is downloaded again only when its content changed.
- Passwords are no longer sent again every round: logins saved by an older Vega that can't be read without a prompt used to make Vega think the job was unfinished.
- Another Mac that re-stamps a login with the same password no longer makes this Mac take it and send it back. Updating your other Macs to this version stops the re-stamping at its source.
- Settings › Sync shows its steps only when you ask for a sync, not for every quiet check.
- The "Vega is available" update card no longer sits on top of the downloads list.

### Privacy and security
Reviewed before release.
- Password sync still never shows a Keychain dialog and never reads an older item that would ask first. The only change to what is read: it looks up a single login instead of scanning all of them.
- Passwords are still sealed with your sync passphrase before they leave this Mac. Vega now keeps the sync files it downloaded in memory between rounds, exactly as they sit in Drive (passwords still sealed); they are dropped when Vega quits.
- Keychain access now runs on a background thread. macOS's switch that silences Keychain dialogs is shared by the whole app, so a dialog that you trigger yourself in the very moment a sync reads could be silenced for that one read; you can ask again.
- No new network destinations, permissions or entitlements: sync talks to the same Google Drive or iCloud Drive folder as before, only less often.

## Vega 1.7.13 (2026-11-18)

### New
- **A redesigned Settings › Passwords.** Each saved login shows its site's icon, with a search field, an Add button and a count above the list. Right-click a login to copy its username or password.
- **A page for each login.** Click one to copy its username or password, show or hide the password, change it in place, open the site in a Vega tab, check it against known leaks, or delete it.
- The switches and Import from CSV now sit together under Options, below your passwords.

### Privacy and security
Reviewed before release.
- A password is shown, copied, changed or checked only after Touch ID or your Mac password. One approval covers that login's page while it is open; the password is kept in memory only until the page closes.
- A copied password still leaves the clipboard after 60 seconds.
- Site icons on the page come only from Vega's own icon cache, so opening Passwords contacts no website. A site without a cached icon shows its first letter.
- The leak check works as before: only the first 5 characters of the password's hash leave your Mac.
- No new network connections, permissions or entitlements.

## Vega 1.7.12 (2026-11-18)

### New
- **Passwords… in a text field's right-click menu.** It shows that field's saved logins, or opens Settings › Passwords when it has none.

### Fixes
- Favorites you haven't opened get their icons again without a click. Vega asked sites for them under its own name, which some (Cosmos among them) refuse; it now asks as Safari. A few sites that block anything but a real browser (Behance, Crunchyroll) still show their icon once opened.
- Site icons are saved in Vega's own cache folder, and every icon is fetched again once, so a favorite that had saved another site's icon shows its own right away. The old shared folder, ~/Library/Caches/FaviconCache, is no longer used.
- A text field's right-click menu keeps Cut, Copy, Paste and spelling. It used to show the page's menu instead.

### Known issue
- macOS's own Passwords AutoFill can appear over Vega's password suggestions. It is drawn by macOS and apps can't turn it off; System Settings › General › AutoFill & Passwords can.

### Privacy and security
Reviewed before release.
- Icon requests now say they come from Safari, as Vega's pages already do, so sites can't tell icon fetches from Vega apart from Safari's. They still go only to each favorite's own site over https, carry no website cookies or sign-ins, and private tabs never make them.
- The page's HTML is read only to find its icon links and is not kept. SwiftSoup, the HTML parser already inside Vega, is now listed as a direct dependency.
- Passwords… from the right-click menu fills nothing by itself: as before, a login is filled only after you pick it and approve with Touch ID or your Mac password.
- No new network connections, permissions or entitlements.

## Vega 1.7.11 (2026-11-18)

### Fixes
- A favorite or pinned tab keeps its own site's icon after its page goes on to another site (a sign-in, a link). On a Mac that had no icon saved for it yet, it could take the other site's icon and keep it. A wrong icon already saved is replaced within a day, or as soon as the favorite shows its own site again.

### Privacy and security
Reviewed before release.
- Icons are fetched as before, from the favorite's own site and only for public https addresses. Private tabs still never fetch or save icons.
- No new network connections, permissions or entitlements.

## Vega 1.7.10 (2026-11-18)

> **Replaces 1.7.9, which was withdrawn.** 1.7.9 started sending space deletions to your other Macs, and a deletion one Mac had held back for days could remove spaces you were still using on another. 1.7.10 fixes that and brings everything 1.7.9 added (listed under 1.7.9 below).

### New
- **Sync progress.** Settings › General › Sync shows a progress bar for each sync round (your other Macs, spaces, passwords, settings, open tabs) and afterwards what is synced: spaces, favorites and pinned tabs, and passwords.
- **Move or copy favorites to another space.** Right-click a favorite: Move to Space, Copy to Space, or Copy All Favorites to Space (it skips addresses the space already has), so a new space can start with your favorites.
- **Reorder spaces in Settings › Spaces.** Drag a space by its row; the others slide out of the way. Move Up and Move Down are in the row's … menu too.
- **Choose where downloads go.** Settings › General › Downloads: Save Downloads To a folder you pick, or Ask where to save each download.

### Fixes
- Sync no longer applies a space deletion that another Mac made before this Mac last heard from it. A new deletion still reaches your other Macs.
- Password sync says how many logins it can't send yet: logins saved by an older Vega stay on their Mac, because macOS asks before Vega may read them. Importing them again (Settings › Passwords › Import from CSV) moves them so they sync.

### Privacy and security
Reviewed before release.
- Counting the logins that can't sync reads only each login's site and user name, never a password, and never shows a Keychain dialog.
- The download folder is a path saved on this Mac. Downloads keep the quarantine flag macOS uses for files from the web, wherever they are saved.
- Copying a favorite copies its address and name inside Vega; nothing leaves the Mac except through sync, as before.
- The 1.7.9 review below still applies. No new network connections, permissions or entitlements.

## Vega 1.7.9 (2026-11-18, withdrawn)

> Withdrawn the same day: it could delete spaces that another Mac had deleted days before. Everything below ships in 1.7.10, with that fixed.

### New
- **Remove a Mac from sync.** Settings › General › Sync lists your other Macs; Remove stops syncing with one at once. The next time Vega opens on it, it turns its sync off and deletes the spaces, favorites, pinned and open tabs, passwords, settings, history and website sign-ins it got through sync (a fresh empty space is left if that was all of them). It can join again by turning sync on. With password sync on, removing a Mac asks for a new passphrase, which locks it out of passwords right away.
- **Short tab names in the sidebar.** Any site's own name is dropped from the tab's title ("Best laptops | The Verge" shows as "Best laptops"), and a long title stops at about 28 characters, at a break or a word and ends in "…". Hover a tab for its full title. A name you gave a tab yourself is left as you wrote it.
- **Scroll through all your spaces in the library.** Under Spaces, a sideways swipe on the trackpad scrolls the columns, and a mouse or an up-and-down scroll moves them sideways instead of scrolling the list inside a space. The swipe closes the library only once the columns are at their edge.
- **Settings sync.** Your settings (search engine, tab behaviour, appearance, keyboard shortcuts, privacy and password switches) travel with your first profile's account. A new Mac takes them when it first signs in, after that the newest change wins, and they apply the next time Vega opens (Settings › General offers Restart Vega). Window sizes, extensions and sync's own state stay on each Mac.
- **Open tabs are kept the same on all your Macs.** A tab you open or close on one Mac opens or closes on the others (Settings › General › Sync › Keep open tabs the same on my Macs, on by default). Each Mac keeps its own selected tab and its own sidebar layout.
- Signing in on first launch also turns on the list under Spaces › Tabs from Other Macs.

### Privacy and security
Reviewed before release.
- Removing a Mac writes a small marker file (`removed/<Mac>.json`) to your own sync folder or Google Drive. Anyone who can write to that folder can already change your synced data, so this adds no new access. The marker only ever tells a Mac to delete what sync gave it.
- A removed Mac deletes only what it got through sync: the synced profile's spaces and tabs, its history, its sync passphrase and the profile's saved passwords in Vega's own Keychain items. Other profiles and other apps' Keychain items are left alone. A Mac that was offline keeps its data until it next opens Vega.
- Removing a Mac with password sync on asks for a new passphrase, so the removed Mac can no longer read passwords from the sync folder.
- The test-only `fork.keychain.testPrefix` setting does nothing unless it is set by hand with `defaults write`; normal installs use the usual Keychain items.
- No new network connections, permissions or entitlements.

### Fixes
- A new Mac that signs in on first launch takes your first profile even though a new install already opens a tab (it used to end up with two profiles). It still never replaces a profile that has favorites or pinned tabs.
- Sync keeps running while Vega is hidden or minimised, instead of waiting until you bring it forward.
- Settings sync no longer writes a file with a broken name. (One file named \(own.uuidString).plist may be left in your sync folder; it is harmless.)
- `defaults write com.vega.browser skipLegacyMigration -bool true` before the first launch starts Vega empty, without importing an older Vega or Nook install's data.
- Spaces deleted when profiles were merged are deleted on your other Macs too. They used to stay there for good, which is how a Mac could show spaces the first one no longer had.

## Vega 1.7.8 (2026-11-16)

> **Passwords and sync now belong to a profile.** Your current profile keeps everything it had: its saved passwords, Google account, sync passphrase and sync switches. A profile you add gets its own, and its spaces and open tabs go only to its own account. Nothing of one profile reaches another's account.

### New
- **Sign in on first launch.** Onboarding now starts with signing in with Google (or iCloud Drive), which turns sync on, with switches for open tabs and passwords. Skip it and Settings › General › Account has the same sign-in.
- **A window per person.** Each window belongs to one profile and shows only its spaces. The space menu lists other profiles with **Open …'s Window**, File › **New Window for Profile** opens one, New Window keeps the profile you're in, and a new profile opens in its own window.
- **Each profile has its own passwords and sync.** Passwords, the Google account, the sync passphrase and the sync switches are per profile, and a profile's spaces and shared open tabs go only to its own account. Settings › General › Account and Sync follow the profile you pick. Your current profile keeps everything it had.
- **Bring a profile to another Mac.** Add Profile › **Sign in with Google…** brings the profile that account holds from your other Mac, with its spaces, and turns its sync on. A fresh Mac that signs in on first launch takes the account's profile as its first one, so it doesn't end up with two.
- **Profile pictures.** Click a profile's picture in Settings › Spaces to pick one of 12 pixel icons in Vega's style or choose a photo.
- **Add and delete profiles.** Add Profile and Delete Profile in Settings › Spaces, so two people can share a Mac with their own spaces and sign-ins. Deleting a profile moves its spaces into the one you pick, which also merges two profiles into one.

### Fixes
- The sync switches (Sync my Macs, Sync with, Share open tabs) redraw as soon as they change.

## Vega 1.7.7 (2026-11-16)

> **Password sync: set up your passphrase again if a Mac asks for one.** Each sync place (iCloud Drive or Google) has its own passphrase. If you switched places, the new one has none yet: on your first Mac turn on **Sync Passwords**, press **Suggest**, copy it, and enter the same passphrase on your other Macs. Forgot it? **Change Passphrase…** sets a new one from any Mac that's already syncing.

### Fixes
- Password sync: turning it off and on again on the same Mac no longer asks for the passphrase. Vega keeps this Mac's key and only asks when the passphrase was changed on another Mac or the sync folder has none yet.
- The Sync Passwords switch shows Off right after you turn it off (it used to look still on, so the next click turned it back on).
- **Change Passphrase…** sets a new sync passphrase from any Mac, and your other Macs say so instead of failing quietly. **Suggest** fills a strong passphrase you can copy into your other Macs, and the sheet says whether you're creating one or entering the one from your other Mac.

## Vega 1.7.6 (2026-11-16)

### Privacy and security
- Filling a saved password asks for Touch ID or your Mac password first, as Apple's Passwords does. One approval covers the same site for a minute, so a sign-in that fills a username and then a password asks once.

- Updates no longer make the Keychain ask about your saved passwords again. Releases are signed with a certificate (an ad-hoc signature is a new identity every build, so every approval was lost). You approve each item once more after this update, then not again.
- Saved passwords live in new Keychain items owned by Vega's stable signature, so the Keychain no longer asks before using them. A password saved by an older build is moved over the first time it is used (one last Keychain dialog for it, plain Allow is enough). Importing the same passwords again moves them all with no dialog.
- Password sync never shows a dialog and no longer reads every saved password at launch. It reads them only when one changed, and a password the Keychain would ask about waits until you have used it.

### Changes
- Every floating page has one look: links from other apps and sign-in pop-ups open in the same card as Peek, over the window you're in. The small separate window is kept for when no Vega window is open.
- Peek's Close, Open as Tab and Split buttons show their icons again.
- Peek's Open as Tab button asks which space to open the page in: the window's own space first, then your other spaces.
- Filling a saved login now fills the username too on sites that keep it outside the password's form.
- Saved passwords are offered under a login field, including a username-only first step. The prompts use Apple's wording: Save Password, Update Password, Not Now, Never for This Website.

## Vega 1.7.5 (2026-11-16)

### Fixes
- The AI chat asks for permission once. **Allow for This Chat** now covers every browser action for the rest of the chat, new sites included, and the on-device model's prompt offers it too. Running a script on a page still asks every time, and so does opening an address with a long query that could carry page text out.
- The send button turns into **Stop** while the AI works, and stops the reply.
- Clearing data when Vega quits no longer answers a restart or log out with a refusal: the quit is held until the clearing is done, then goes through.

## Vega 1.7.4 (2026-11-16)

Easels, an AI chat that works with your own providers, and a floating chat.

### New
- **AI chat with your own provider and API key.** Add any OpenAI-compatible service (OmniRoute, LM Studio, Groq and more) in Settings › AI, with its address and API key. Use Gemini, OpenRouter or Ollama too, and several providers at once: the chat's model list shows the models you chose from each, and picking one switches the chat to that provider.
- **Choose your models.** Fetch Models lists what a provider offers; switch on the ones you want in the chat. A model is tested with a one-token request first, and Gemini has a Turn on working models button. Providers can be removed.
- **Floating or docked chat.** Settings › AI › Chat Position, or the button in the chat header. Floating keeps the page at full width, with the header as the drag handle. The chat is always on the right and never takes the tab sidebar's side.
- **Easels.** Spaces › Easels › New Easel opens a freeform canvas. Drag in images, links or text, add notes, or use Spaces › Easels › Add This Page. Cards move and resize; a page card opens in a new tab. Easels save on their own.
- **Summarize my open tabs.** Ask Vega reads your open tabs and groups and summarizes them. Spaces › Summarize Open Tabs, or the starter in the chat.
- **Browse the web for me.** Describe what you want to know; Ask Vega researches it and builds a page of what it found, opened as a tab. Spaces › Browse the Web for Me…. Needs a model that can use tools (not On-Device).
- **Share a space.** Spaces › Share Space… sends a space and its tabs to someone; they open the file and Vega adds it as a new space. Export Space… saves the file, Open Shared Space… opens one.
- **Tabs from other Macs.** Turn on Settings › General › Share open tabs, and Spaces › Tabs from Other Macs lists what's open on your other Macs. Off by default.

### Privacy and security
- **Your keys stay put.** An API key is only sent over https:// (or to this Mac), and keys stay on this Mac's Keychain, not in backups or other devices.
- **Pages Ask Vega builds can't phone home.** They show text and web links only: no scripts, no remote images, no media, no file or app links. They are deleted after 30 days.
- **Easel cards** only open web addresses, and their images can't point outside the Easels folder.
- **Model tools ask in plain words.** "Let Vega's AI open google.com in a new tab?" with Don't Allow, Allow Once and Allow for This Chat: no code shown. Allow for This Chat still asks again before the AI opens a site it hasn't opened yet, and before it shows you a page it wrote. Private windows never use tools.
- **You can see what leaves your Mac.** The chat header says whether the page stays on this Mac or is shared with your provider, and each provider has a switch to stop sending the page. Private windows never send a page.
- **Synced open tabs are sealed.** With password sync on, the list of open tabs is encrypted with your passphrase and keeps full addresses; without it, it's plain text with no query strings.
- **Clear on quit.** Settings › Privacy can erase cookies, site data and history each time you quit.
- **Hide your address from WebRTC.** An option in Settings › Privacy makes calls connect through a relay, so a site can't read your network address.
- **Leaked password check.** Passwords › ⋯ › Check if Leaked asks Have I Been Pwned using only the first 5 characters of the password's hash.
- **Easel pictures** are limited to 25 MB and scaled down.
- **Cleaner summaries.** Summarize my tabs sends addresses without query strings, and skips the text of sign-in pages.
- **Synced and shared tabs** drop query strings and logins from addresses. Opening a shared space adds it without opening any page.

### Ad blocking
- **Pop-up ads.** Ad scripts that open a window on any click, whether with `window.open` or by clicking a hidden link, are stopped. A window to another site opens only for the link you actually clicked, or a sign-in, payment or share window (Share buttons for X, Facebook, WhatsApp and the like still work); same-site windows still open. Turn it off in Settings › Privacy › Pop-ups (applies after a restart).
- **Brave's lists.** Brave Unbreak (the rules for streaming sites, including their daily-changing ad domains), Brave Specific, Brave Social, Brave First Party and Brave's cookie-notice list are now on by default, along with a current malware list. A test of Brave's generic ad-path rules blocks in Vega.
- **Quiet blocking, like Brave.** An ad a page tries to open or send you to is dropped without a word: no "Vega blocked this page" card and no empty tab. The card still shows for an address you asked for.
- **Ads laid over videos.** A transparent link to another site covering the page is ignored and removed, so the click reaches the player.
- When the lists are bigger than Vega's rule limit, hiding rules are cut before blocking rules, so more ads and trackers are stopped.

### Fixes
- API keys save with Save or Return; typing no longer drops the field's focus.
- A connection test marks only the provider you tested, and says why it failed.
- The chat's header and input sit on blurred glass, and the AI panel's resize line matches the sidebar's.

## Vega 1.7.3 (2026-11-14)

Icons that move, a calmer AI chat, and a reader view.

### New
- **Animated icons.** The sidebar, tabs, library, Settings and more use icons that move when you point at them. Menus show the same icons, still.
- **Reader view.** View › Show Reader (⌥⌘R), or the book button in the address bar, shows an article without the clutter: text size, a light, sepia or dark page, and Esc to leave. The page underneath is untouched.
- **Ask Vega, redone.** A clean header that names the page you're asking about, one-tap starters, a clearer input with the model picker lined up under it, and a copy button under each reply that never covers text.

### Faster
- **Lighter ad blocker.** Vega now hands the web engine at most 150,000 blocking rules, so pages open faster. The 108,000-rule malware list is optional.

### Fixes
- Extensions no longer open their welcome or what's-new tabs each time Vega updates.
- A page's own HTML no longer downloads when Vega reopens with a tab restored, or when you Option-click a link inside Peek.
- A download with no address no longer sits in the library keeping its ring on the library button.
- The Peek card's site name and buttons stay readable over any window; the buttons are now round glass buttons beside the card.
- The AI chat button is back in the bottom bar, with the space dots closer together.

## Vega 1.7.2 (2026-11-13)

Faster page loads, and a new home for updates.

### Fixes
- **Pages load faster.** Vega no longer stalls on every navigation while it re-checks the ad blocker's scripts.
- Updates now come from Vega's renamed GitHub repository. Copies installed before 1.7.2 may need a fresh download of this version.

## Vega 1.7.1 (2026-11-13)

Small fixes to updating.

### Updates
- **Check for Updates…** in the Vega menu works again.
- After an update, the "What's new" card opens the Updates page in Settings.
- The update window no longer shows a web page of release notes.

## Vega 1.7.0 (2026-11-13)

Your passwords, and your setup on every Mac.

### Passwords
- **Save and fill logins.** Vega offers to save a login after you sign in, and lists your saved logins under a login field. Nothing is filled until you click one. Private windows never save or fill.
- **Kept in your Mac's Keychain.** The new Passwords page in Settings opens only after Touch ID or your Mac's password, every time.
- **Manage them:** search, copy, edit, delete, add by hand, and import a file exported from Chrome or Safari.

### Sync between your Macs
- **Sync my Macs** keeps your spaces, favorites and pinned tabs the same everywhere. Open tabs stay on each Mac.
- **Choose where it syncs:** iCloud Drive, or a Google account (the files go in a hidden folder of your Google Drive that only Vega can open). Both work without any paid account.
- **Passwords sync too, encrypted** with a passphrase only you know, so neither iCloud nor Google can read them.

### Updates
- A new **Updates** page shows your version, an automatic-update switch, Check for Updates, and what changed in every version.
- The sidebar notice names the new version and links to What's New.

### Also
- File › New Little Window (renamed from its old name).

## Vega 1.6.0 (2026-11-13)

The first public Vega release, built on Nook 1.6.0.

### Sidebar and browsing
- **Sidebar** reworked: 247 pt wide, 32 pt buttons, tighter insets and title row, a cleaner address field, an 8 pt page frame.
- **Hover sidebar** (when the sidebar is collapsed) carries the window buttons inside the panel.
- **Command palette** redesigned: centred dark glass, your open tabs listed before you type (from every space, each labelled with its space), smaller text, an accent-filled selected row.
- **Page loading** shows as a tint in the space's colour sweeping across the address field.
- **Site Controls panel** redesigned, with per-site settings: JavaScript on or off, the mobile version of a site, automatic picture-in-picture.
- **Extensions:** pinned extensions show in the address field on hover; right-click one for Remove, Pin/Unpin, Manage and Permissions.
- **Notes** in the sidebar.
- **Menu bar commands:** Clear Today, Reset All Tabs in This Space, Reveal Tab in Sidebar, Stay on Top, Copy URL as Quote, Save Page As, a small floating window, Expand/Collapse Pinned Tabs, View Archive and Clear Archive, Add Split View, focus the next or previous split pane, Show Full URL, Merge All Windows and more.
- **Favorites** with 16 pt icons and a thinner page frame.

### New features
- **Picture-in-picture** opens in a floating window by default; drag it into the sidebar and Vega remembers, pull it out and it floats again.
- **Cast** (File › Cast…): AirPlay the page's video from a bar in the sidebar.
- **Capture** (File › Capture Visible Area / Capture Full Page) to PNG.
- **Media** in the Library: images and videos you downloaded, as a searchable grid.
- **Downloads:** a context menu (Copy Image, Messages, AirDrop, Preview, Show in Finder, Hide, Move to Trash), drag a file out of the list anywhere, a download ring in the footer.
- **Blank Window** (File menu) and **Change Profile** (Spaces menu).

### Settings
- Redesigned to match macOS 27 System Settings: glass sidebar with search, a header card per page, back and forward like System Settings, calmer grouped pages.
- Profiles get an info sheet (rename, which spaces use it, website data); Site Search uses a + / − list; clearing history asks first.
- Reopens on the page you last used.

### Look and accessibility
- Liquid Glass for the palette, address panel, Site Controls and floating chrome, solid under Reduce Transparency.
- Reduce Motion and Increase Contrast respected throughout; VoiceOver names for favorites; no text below the 10 pt minimum.
- Sharp, same-size favicons with no coloured glow; icons found for sites that hid them.

### Fixes
- Favicons that were missing or blurry on favorites and pinned tabs.
- The sidebar's back, forward and reload buttons no longer vanish when the sidebar is narrow, and resizing it no longer drags the whole window.
- The downloads list stays open while you use its menu, drag a file out, or trash one.
- A private-window favicon leak, notes not saved on quit, and an icon cache that grew without limit.

### Under the hood
- Its own app: bundle ID `com.vega.browser` and the `vega://` scheme. Data from an existing Nook install moves over on first launch.
- Updates itself (Sparkle) from this repository's releases.
- One-command releases (`scripts/release.sh`, see [docs/RELEASING.md](docs/RELEASING.md)) and a daily sync with upstream Nook.

### Not yet
- Notarization (no "Open Anyway" step) and web push notifications need the paid Apple Developer Program; the release script turns them on once it's set up.
"""#
