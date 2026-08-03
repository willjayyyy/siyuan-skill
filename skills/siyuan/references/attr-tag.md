# Attributes, tags, bookmarks

## Block attributes

```bash
$sy /api/attr/getBlockAttrs -d '{"id":"<id>"}'
$sy /api/attr/setBlockAttrs -d '{"id":"<id>","attrs":{"custom-source":"claude","name":"alias"}}'
$sy /api/attr/batchGetBlockAttrs -d '{"ids":["<id1>","<id2>"]}'
$sy /api/attr/batchSetBlockAttrs -d '{"blockAttrs":[{"id":"<id>","attrs":{...}}]}'
```

- Attribute names must match `[a-z][a-z0-9-]*`. CJK, underscores and
  digit-initial names are **rejected** with
  an error stating names may contain only lowercase letters, digits and hyphens.
- **Uppercase is NOT rejected — it is silently lowercased.** `CustomFoo` becomes
  `customfoo`, and `Custom-Source` silently lands on `custom-source`, overwriting
  it. Always write the name in lowercase yourself so you can see the collision.
- Arbitrary names are allowed, not just `custom-` ones. But **prefix your own
  with `custom-`** anyway: unprefixed names risk colliding with SiYuan's own
  (`name`, `alias`, `memo`, `bookmark`, `title`, `type`, `id`, `updated`,
  `style`, `icon`), which the UI and export logic read.
- `setBlockAttrs` **merges** — existing keys not mentioned survive. Set a value
  to `""` to remove that key.
- `resetBlockAttrs` is **deprecated and does nothing** in v3.7.3 (the router
  binds it to a `deprecated` stub; it returns
  `[/api/attr/resetBlockAttrs] is deprecated`). To clear attributes, call
  `setBlockAttrs` with `""` values.
- Attributes are queryable, which makes them the right place for archival
  metadata:
  ```sql
  SELECT b.hpath FROM blocks b JOIN attributes a ON a.block_id=b.id
  WHERE a.name='custom-source' AND a.value='claude'
  ```

### Suggested archival convention

When this skill writes a document, stamp the document block so it stays
identifiable and re-findable later:

```json
{"custom-source":"claude","custom-archived":"2026-08-03","custom-topic":"<topic>"}
```

Read them back with `getBlockAttrs`, or join `attributes` in SQL as above.

## Tags

SiYuan tags are `#tag#` inline in block content — writing one is just writing
markdown. The `tag` column on `blocks` mirrors them.

```bash
$sy /api/tag/getTag                                        # full tag tree
$sy /api/tag/renameTag -d '{"oldLabel":"old","newLabel":"new"}'
$sy /api/tag/removeTag -d '{"label":"tag"}'   # guarded, needs -y
```

`renameTag`/`removeTag` rewrite every block containing the tag. `removeTag` is
on the danger list.

Nested tags use `/`: `#tech/Java#`.

## Bookmarks and memos

`bookmark` and `memo` are plain block attributes:

```bash
$sy /api/attr/setBlockAttrs -d '{"id":"<id>","attrs":{"bookmark":"todo","memo":"note"}}'
$sy /api/bookmark/getBookmark
```
