# Blocks

57 endpoints (`sy api block`). Blocks are the unit of everything in SiYuan: a
document is a block, every paragraph/heading/list-item is a block with its own ID.

All insert/update endpoints take `{data, dataType}` where `dataType` is
`"markdown"` or `"dom"`. Use `"markdown"` unless you have a reason not to.

## Append (the archiving workhorse)

```bash
$sy append <parentID> <md-file|->        # wraps /api/block/appendBlock
```
`{parentID, data, dataType}`

- **`parentID` must be a container block** — document `d`, blockquote `b`,
  list `l`, list item `i`, super block `s`, or `callout`. Passing a leaf block
  (paragraph, heading, code, table) fails with
  `... is a leaf block and cannot have children; use previousID ...` — switch to
  `insertBlock` with `previousID`. Headings get their own longer variant of that
  message telling you to pass the heading (or the last block under it) as
  `previousID`. When in doubt, pass the document ID.
- Multi-block markdown is fine: headings, lists and code fences all come through
  as separate blocks.
- `prependBlock` is the same shape, inserting at the top.
- `/api/block/appendDailyNoteBlock` `{notebook, data, dataType}` appends to
  today's daily note, creating it if needed — good for running logs.

## Insert at a precise position

```bash
$sy /api/block/insertBlock -d @payload.json
```
`{data, dataType, previousID?, nextID?, parentID?}` — supply exactly one anchor.
`previousID` inserts after that block (most common), `nextID` before it,
`parentID` as first child.

## Update / move / delete

```bash
# replace a block's whole content
$sy /api/block/updateBlock -d '{"id":"<blockID>","dataType":"markdown","data":"new content"}'
# move
$sy /api/block/moveBlock -d '{"id":"<blockID>","parentID":"<newParent>","previousID":"<after>"}'
# delete — guarded, needs -y
$sy /api/block/deleteBlock -d '{"id":"<blockID>"}'
```

`updateBlock` **replaces**, it does not merge. To edit part of a block, read
its markdown first:
`$sy /api/block/getBlockKramdown -d '{"id":"<id>"}' -q '.kramdown'`

Batch variants exist (`batchUpdateBlock`, `batchInsertBlock`,
`batchAppendBlock`) taking arrays — cheaper than looping, and atomic per call.

## Inspect

```bash
$sy /api/block/getChildBlocks -d '{"id":"<id>"}' -q '[.[]|{id,type}]'   # document order
$sy /api/block/getBlockInfo   -d '{"id":"<id>"}'      # box, path, rootID, rootTitle, rootIcon — NO type field
$sy /api/block/getBlockBreadcrumb -d '{"id":"<id>"}'  # ancestor chain
$sy /api/block/checkBlockExist -d '{"id":"<id>"}'
$sy /api/block/getRefIDs -d '{"id":"<id>"}'           # who references this block
```

`getChildBlocks` returns children **in document order** — SQL cannot do that
(`sort` is a block-type rank, not a position; see `query-sql.md`). Use SQL for
filtering/counting/projection, `getChildBlocks` whenever order matters.

## Traps

- IDs returned by insert/append are in `.[0].doOperations[].id` — the response is
  a transaction log, not a plain object. Project it:
  `-q '[.[].doOperations[]?|{id,action}]'`
- Folding (`foldBlock`/`unfoldBlock`) changes the `ial`, not the content.
- Task list markers have their own endpoint
  (`updateTaskListItemMarker`); rewriting `- [ ]` via `updateBlock` works but
  regenerates the block ID's children.
- After writing, verify with a projected `sy sql`, remembering the index lags.
