// Licensed under GPL-3.0. See LICENSE.
//
//  PageSession+Blockable.swift
//  Vega
//
//  PageSession satisfies VegaBlocker's page seam as-is: itemID, isOAuthFlow and
//  webView are already its own stored properties. Task 6 moves this into VegaWeb.
//

import VegaBlocker

extension PageSession: BlockablePage {}
