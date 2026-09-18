// Licensed under GPL-3.0 with the App Store exception in LICENSE-EXCEPTION.md.
//
//  Main.swift
//  Vega
//
//  The process entry. The bundle-id migration must finish before VegaApp's stored properties are
//  built, since those already read UserDefaults and Application Support.
//

@main
enum Main {
    static func main() {
        LegacyDataMigration.migrateIfNeeded()
        VegaApp.main()
    }
}
