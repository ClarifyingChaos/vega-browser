# Vega changelog

What Vega changes on top of [Vega](https://github.com/nook-browser/Nook). Vega's own changes reach Vega through the daily upstream sync; they're in [CHANGELOG.md](CHANGELOG.md) and [Vega's releases](https://github.com/nook-browser/Nook/releases).

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

The first public Vega release, built on Vega 1.6.0.

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
- Its own app: bundle ID `com.vega.browser` and the `vega://` scheme. Data from an existing Vega install moves over on first launch.
- Updates itself (Sparkle) from this repository's releases.
- One-command releases (`scripts/release.sh`, see [docs/RELEASING.md](docs/RELEASING.md)) and a daily sync with upstream Vega.

### Not yet
- Notarization (no "Open Anyway" step) and web push notifications need the paid Apple Developer Program; the release script turns them on once it's set up.
