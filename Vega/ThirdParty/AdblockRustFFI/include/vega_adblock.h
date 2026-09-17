// vega_adblock.h
// C ABI over brave/adblock-rust (MPL-2.0) built from Vega/ThirdParty/AdblockRustFFI.
//
// THREAD SAFETY: an engine pointer is NOT thread-safe. adblock::Engine is Send
// but not Sync (it holds a RefCell regex cache). The caller must serialize all
// calls on a given engine (e.g. confine it to one actor/queue). Distinct
// engines may be used from distinct threads concurrently.

#ifndef VEGA_ADBLOCK_H
#define VEGA_ADBLOCK_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Build an engine from ABP/uBlock Origin filter-list text (UTF-8, not NUL-terminated).
/// Returns NULL on failure. Free with vega_adblock_engine_free.
void *vega_adblock_engine_from_rules(const char *rules_utf8, size_t rules_len);

/// Restore an engine from bytes produced by vega_adblock_engine_serialize.
/// Returns NULL on failure (corrupt data or version mismatch).
void *vega_adblock_engine_deserialize(const uint8_t *bytes, size_t len);

/// Serialize an engine. Writes the byte count to *out_len. Returns NULL on
/// failure. Free the buffer with vega_adblock_buffer_free.
uint8_t *vega_adblock_engine_serialize(void *engine, size_t *out_len);

/// Free a buffer returned by vega_adblock_engine_serialize. NULL is a no-op.
void vega_adblock_buffer_free(uint8_t *bytes, size_t len);

/// True if the request would be blocked (matched a block rule with no
/// exception, or an $important rule). request_type is one of adblock-rust's
/// strings: "script", "image", "stylesheet", "xmlhttprequest", "sub_frame",
/// "main_frame", "font", "media", "websocket", "ping", "object", "other".
/// Returns false on NULL engine, NULL/non-UTF-8 arguments or unparseable URLs.
bool vega_adblock_engine_matches(void *engine, const char *url, const char *source_url, const char *request_type);

/// Free an engine. NULL is a no-op.
void vega_adblock_engine_free(void *engine);

/// Convert ABP/uBlock filter text (UTF-8, not NUL-terminated) into a
/// NUL-terminated UTF-8 JSON array of WKContentRuleList rule objects.
/// Writes the converted rule count to *out_rule_count and the number of lines
/// that failed to convert to *out_error_count; either pointer may be NULL.
/// Returns NULL on a NULL or non-UTF-8 input.
/// Free the result with vega_adblock_string_free.
char *vega_adblock_convert_to_content_blocking(const char *rules_utf8, size_t rules_len, size_t *out_rule_count, size_t *out_error_count);

/// Free a string returned by any char*-returning function in this library.
/// NULL is a no-op.
void vega_adblock_string_free(char *s);

#ifdef __cplusplus
}
#endif

#endif /* VEGA_ADBLOCK_H */
