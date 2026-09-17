# Vega App Store Distribution Exception

Vega is licensed under GPL-3.0. See [LICENSE](./LICENSE).

## Additional permission under GNU GPL version 3 section 7

> As additional permission under section 7, you are allowed to distribute the
> software through an app store, even if that store has restrictive terms and
> conditions that are incompatible with the GPL, provided that the source is
> also available under the GPL with or without this permission through a
> channel without those restrictive terms and conditions.

The proviso is the point. Vega's complete corresponding source stays public at
<https://github.com/l984-451/Vega> under plain GPL-3.0, with no additional
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

## Who granted this

Every copyright holder of Vega's own code has granted this permission. The
maintainer keeps the records outside this repo.

### Third-party code

The exception covers Vega's own source. It does not reach code Vega links that
others license under GPL-3.0, because Vega cannot add permissions to work it
does not own. As of this date that means AdGuard's SafariConverterLib and the
`@adguard/safari-extension` bundle inside `vega-advanced-blocking.js`, both of
which are being replaced by `adblock-rust` under MPL-2.0. See
[the iOS port design](./docs/superpowers/specs/2026-09-17-ios-port-design.md).

The filter lists under `Vega/Managers/ContentBlockerManager/Resources/` are
data rather than linked code, and travel as separate works under their own
terms.

### Not legal advice

This file was drafted by the maintainer with AI assistance. The wording follows
an established form used by other GPL projects for the same purpose. Have a
lawyer read it before the first App Store submission.
