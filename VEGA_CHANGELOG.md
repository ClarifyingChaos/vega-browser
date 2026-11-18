# Vega changelog

What Vega changes on top of [Nook](https://github.com/nook-browser/Nook). Nook's own changes reach Vega through the daily upstream sync; they're in [CHANGELOG.md](CHANGELOG.md) and [Nook's releases](https://github.com/nook-browser/Nook/releases).

## Vega 1.7.12 (2026-11-18)

### Fixes
- Site icons are saved in Vega's own cache folder, and every icon is fetched again once. A favorite that had saved another site's icon (Cosmos showed the wrong one on some Macs) shows its own again right away, instead of after a day. The old shared folder, ~/Library/Caches/FaviconCache, is no longer used.

### Privacy and security
Reviewed before release.
- Icons are fetched once more from each favorite's own site, public https only, as before. Private tabs never fetch or save icons.
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
