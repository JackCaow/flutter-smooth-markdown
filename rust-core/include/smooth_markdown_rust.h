#ifndef SMOOTH_MARKDOWN_RUST_H
#define SMOOTH_MARKDOWN_RUST_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Owned bytes; copy/decode before freeing. Free exactly once via this library. */
typedef struct SmrBuffer {
    const uint8_t *data;
    size_t len;
    void *owner;
} SmrBuffer;
enum { SMR_OK = 0, SMR_INVALID_INPUT = 1, SMR_LIMIT_EXCEEDED = 2, SMR_INTERNAL_ERROR = 3, SMR_CALLBACK_ERROR = 4 };
enum { SMR_GFM = 1, SMR_NATIVE_EXTENSIONS = 2, SMR_ESCAPE_HTML = 4, SMR_TRANSPARENT_TABLE_PARTS = 8, SMR_HOST_FENCED_BLOCKS = 16 };
uint32_t smr_abi_version(void);
int32_t smr_parse_utf16(const uint16_t *source, size_t length, uint32_t options, SmrBuffer *result);
/* Single-owner, non-concurrent stream session. Options are SMR_GFM/extensions.
   update accepts the complete current prefix; non-append edits replace all blocks.
   Output is SMR1 with a full-source root span and replacement tail children.
   Retain exactly retained_blocks old top-level children, then append output children.
   Reference definitions conservatively invalidate the entire tree. No host hooks.
   Failure invalidates the session; the next successful update replaces all blocks.
   Decode output against the supplied source before freeing it; free session once. */
void *smr_stream_new(uint32_t options);
int32_t smr_stream_update_utf16(void *session, const uint16_t *source, size_t length,
                               SmrBuffer *result, uint32_t *retained_blocks);
/* Optional ABI-1 extension: append just the new UTF-16 suffix. Same retention,
   limits and invalidation as update. Empty suffix is an unchanged publication.
   A later update may still replace the entire source. */
int32_t smr_stream_append_utf16(void *session, const uint16_t *suffix, size_t length,
                               SmrBuffer *result, uint32_t *retained_blocks);
void smr_stream_free(void *session);
typedef struct SmrMatch { uint32_t consumed; uint32_t id; } SmrMatch;
typedef int32_t (*SmrInlineCallback)(void *,const uint16_t *,size_t,uint32_t,uint32_t,SmrMatch *);
typedef int32_t (*SmrBlockCallback)(void *,const uint16_t *const *,const size_t *,size_t,uint32_t,uint32_t,SmrMatch *);
typedef int32_t (*SmrInlineContextCallback)(void *,const uint16_t *,size_t,int32_t);
typedef int32_t (*SmrBlockContextCallback)(void *,const uint16_t *const *,const size_t *,size_t,int32_t);
/* Optional scope notifications: begin=1, end=0. Nested scopes unwind in order.
   They permit bridge adapters to reuse immutable host contexts rather than copying per candidate. */
typedef struct SmrHooks { void *context; SmrInlineCallback inline_callback; SmrBlockCallback block_callback;
    SmrInlineContextCallback inline_context; SmrBlockContextCallback block_context; } SmrHooks;
/* SMR_HOST_FENCED_BLOCKS permits a block hook to claim a complete fenced construct
   at its opening line. Ordinary fenced bodies are always protected.
   Synchronous borrowed callbacks: 0 miss, 1 match, negative abort. Inline consumed is UTF16;
   block consumed is line count. IDs must be positive and are returned as Custom.label. */
int32_t smr_parse_with_hooks_utf16(const uint16_t *,size_t,uint32_t,const SmrHooks *,SmrBuffer *);
int32_t smr_parse_inline_utf16(const uint16_t *,size_t,uint32_t,const uint8_t *,size_t,const SmrHooks *,SmrBuffer *);
/* Mutable AST input uses explicit SMR1 strings. Output is raw little-endian UTF16. */
int32_t smr_render_ast_utf16(const uint8_t *,size_t,uint32_t,SmrBuffer *);
int32_t smr_export_html_utf16(const uint16_t *,size_t,uint32_t,SmrBuffer *);
void smr_buffer_free(SmrBuffer *buffer);
/* Syntax highlighting. Language is a UTF-8 fence tag, extension or file name.
   Result: "SMH1", u32 count, then count x (u32 start, u32 length, u32 kind) in UTF16 units. */
int32_t smr_highlight_utf16(const uint16_t *source, size_t length, const uint8_t *language, size_t language_length, SmrBuffer *result);
/* Canonical UTF-8 language name, or an empty buffer when unsupported. */
int32_t smr_highlight_language(const uint8_t *language, size_t language_length, SmrBuffer *result);
/* Whole-input highlighting split into display lines; tabs expand to tab_width spaces (0 keeps them).
   Result: "SML1", u32 lines, per line: u32 length, u16 units, u32 tokens, tokens x (u32 start, u32 length, u32 kind). */
int32_t smr_highlight_lines_utf16(const uint16_t *source, size_t length, const uint8_t *language, size_t language_length, uint32_t tab_width, SmrBuffer *result);
/* Unified diff rows with per-side highlighting and word changes.
   Result: "SMD1", u32 rows, per row: u32 kind (0 hunk, 1 context, 2 added, 3 removed, 4 note),
   u32 line number, u32 changed start, u32 changed length (0xffffffff when absent), then a line as above. */
int32_t smr_diff_utf16(const uint16_t *patch, size_t length, const uint8_t *language, size_t language_length, uint32_t tab_width, SmrBuffer *result);
#ifdef __cplusplus
}
#endif
#endif
