# Vega App Store Distribution Exception

Vega is licensed under GPL-3.0. See [LICENSE](./LICENSE).

## Additional permission under GNU GPL version 3 section 7

> As additional permission under section 7, you are allowed to distribute the
> software through an app store, even if that store has restrictive terms and
> conditions that are incompatible with the GPL, provided that the source is
> also available under the GPL with or without this permission through a
> channel without those restrictive terms and conditions.

The proviso is the point. Vega's complete corresponding source stays public at
<https://github.com/nook-browser/Nook> under plain GPL-3.0, with no additional
terms and no acceptance required. Anyone who receives Vega through Apple's App
Store can obtain that source from a channel Apple does not govern.

This is an additional permission within the meaning of GPL-3.0 section 7. You
may remove it from any copy of Vega you convey, and removing it leaves your
rights under GPL-3.0 unchanged.

This permission covers distribution only. It grants no rights in the Vega name,
wordmark, or icon. See [TRADEMARK.md](./TRADEMARK.md).

## Source file notice

Section 7 requires that added terms appear in the relevant source files, either
in full or as a pointer. Vega uses a pointer. Files carrying the exception
begin with:

```
// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
```

### Third-party code

The exception covers Vega's own source. It does not reach code Vega links that
others license under GPL-3.0, because Vega cannot add permissions to work it
does not own.

Vega links uBlock Origin's scriptlet library, vendored verbatim at commit
`e530864c464e912840e72b60e9f072bc54daba5e` under
[`Packages/VegaBlocker/ThirdParty/ubo-scriptlets/`](./Packages/VegaBlocker/ThirdParty/ubo-scriptlets/).
Copyright (C) 2019-present Raymond Hill, GNU GPL version 3 or later. Each file
keeps its original header and none is modified.

The macOS build ships it and is distributed as a notarized DMG, not through an
app store. The iOS build excludes it, since the App Store is its only channel;
the exclusion is a single `#if os(iOS)` in
[`ScriptletResources.swift`](./Packages/VegaBlocker/Sources/VegaBlocker/ScriptletResources.swift).

The filter lists under `Packages/VegaBlocker/Sources/VegaBlocker/Resources/` are
data rather than linked code, and travel as separate works under their own
terms.

### Not legal advice

This file was drafted by the maintainer with AI assistance. The wording follows
an established form used by other GPL projects for the same purpose. Have a
lawyer read it before the first App Store submission.
