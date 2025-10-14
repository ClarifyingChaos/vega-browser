# Smart Shortcut Debug Instructions

## 🔍 What to Test

Now that I've added extensive debug logging, here's how to test the smart shortcut system:

## 📱 Step 1: Check Basic Setup

**Launch the app and look for these console messages:**
```
🧪 VegaApp onAppear - SmartShortcutManager initialized: [SmartShortcutManager instance]
🧪 VegaApp onAppear - BrowserManager set in SmartShortcutManager: true
🧪 ContentView onAppear - SmartShortcutManager available: true
🧪 ContentView onAppear - BrowserManager available: true
```

If you don't see these messages, the SmartShortcutManager isn't being properly initialized.

## ⌨️ Step 2: Test Keyboard Shortcuts

**Try these shortcuts and look for debug logs:**

1. **Press ⌘R (Refresh)**
   - Expected logs:
   ```
   🔧 [KeyboardShortcutManager] Key pressed: 'r' with modifiers: [command]
   🔧 [KeyboardShortcutManager] Checking shortcut: Refresh - ⌘R
   🔧 [KeyboardShortcutManager] Match found! Checking with smart shortcut manager...
   🔧 [KeyboardShortcutManager] SmartShortcutManager instance: [instance]
   🎹 Smart shortcut manager handling: Refresh (⌘R)
   ```

2. **Press ⌘T (New Tab)**
   - Should trigger similar logs for new tab

3. **Press ⌘W (Close Tab)**
   - Should trigger similar logs for close tab

## 🌐 Step 3: Test Google Docs Detection

1. **Navigate to docs.google.com**
2. **Press ⌘R**
3. **Expected logs:**
   ```
   🎹 Smart shortcut manager handling: Refresh (⌘R)
   🌐 Potential web app shortcut detected: Refresh (Google Docs: true)
   ⏰ Starting web app detection for Refresh
   🍞 Showing toast for Refresh
   🍞 Toast state: show=true, message='Press ⌘R again to refresh', shortcut='⌘R'
   ```

## 🍞 Step 4: Check Toast Display

If you see the "Toast state" logs but no visual toast, the issue is in the UI layer:
- Check that SmartShortcutManager is passed to WebsiteView as environment object
- Verify the @Observable macro is working
- Check that the toast condition is being evaluated

## 🔧 Common Issues & Solutions

### Issue: No logs at all
- **Problem**: KeyboardShortcutManager not being called
- **Fix**: Check global monitor setup in KeyboardShortcutManager

### Issue: Logs stop at KeyboardShortcutManager
- **Problem**: SmartShortcutManager.handleShortcutPressed not being called
- **Fix**: Check if smartShortcutManager is nil or not properly connected

### Issue: SmartShortcutManager logs appear but no toast logs
- **Problem**: shouldShowToastForCurrentSite returning false
- **Fix**: Check URL detection logic and web app candidate logic

### Issue: Toast logs appear but no visual toast
- **Problem**: UI not updating despite state changes
- **Fix**: Check @Observable macro and environment object propagation

## 🎯 Quick Test

To manually trigger a toast (if debugging UI), you can temporarily add this to any view:

```swift
Button("Test Toast") {
    smartShortcutManager.showToast = true
    smartShortcutManager.toastMessage = "Press ⌘S again to save"
    smartShortcutManager.toastShortcut = "⌘S"
}
```

## 📝 What to Report

Please share:
1. Which debug messages you see (and which you don't)
2. What happens when you press ⌘R, ⌘T, ⌘W
3. Whether you're on Google Docs or another site
4. Whether you see any toast UI

This will help identify exactly where the issue is in the chain!