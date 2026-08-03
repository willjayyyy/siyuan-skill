# Documents (filetree)

34 endpoints; the ones that matter are below. `sy api filetree` lists all.

## Create

```bash
$sy newdoc <notebookID> "/Parent/2026-08-03-title" <md-file|->
```
wraps `POST /api/filetree/createDocWithMd`
`{notebook, path, markdown, parentID?, tags?, id?, withMath?, clippingHref?}`

- **`path` here is the hpath** (human path), despite the name. Missing parent
  levels are created automatically as empty documents.
- The last path segment becomes the document title. A leading `# Title` in the
  markdown becomes an h1 *inside* the doc — it does not set the title. Either
  drop it or accept the duplication.
- Returns the new document ID.
- Calling it twice with the same hpath **creates a second document**, it does not
  update. Check first:
  `$sy sql "SELECT id FROM blocks WHERE type='d' AND hpath='/Parent/Title'"`
- You may pass your own `id` (`yyyyMMddHHmmss-xxxxxxx`). This does **not** make
  the call idempotent — a re-run fails with a duplicate-filename error. It prevents duplicates
  rather than updating in place.

`POST /api/filetree/createDoc` `{notebook, path, title, md, sorts}` takes the
internal `.sy` path instead — prefer `createDocWithMd`.

`POST /api/filetree/createDailyNote` `{notebook, app}` creates/returns today's
daily note; combine with `/api/block/appendDailyNoteBlock` to log into it.

## Read

```bash
# hpath -> IDs
$sy /api/filetree/getIDsByHPath -d '{"notebook":"<nbID>","path":"/Parent/Title"}'
# ID -> hpath
$sy /api/filetree/getHPathByID -d '{"id":"<docID>"}'
# children of a path (tree browsing)
$sy /api/filetree/listDocsByPath -d '{"notebook":"<nbID>","path":"/"}' -q '.files[]|{id,name}'
# fuzzy search — matches the document TITLE only, never body text
$sy /api/filetree/searchDocs -d '{"k":"keyword"}' -q '.[]|.hPath'
```

`searchDocs` returns `{box, boxIcon, hPath, path}` — **no `id`**, and its
`hPath` is prefixed with the notebook name (`My Notebook/Notes/Example`), unlike the
`hpath` column in SQL. To get an ID, follow up with
`getIDsByHPath`, or just search in SQL instead:
`SELECT id,hpath FROM blocks WHERE type='d' AND content LIKE '%keyword%'`
(SQL also searches body text, which `searchDocs` does not).

**Do not use `/api/filetree/getDoc`** for reading content — it returns editor DOM
(50–80 KB). Use the SQL recipes in `query-sql.md`.

## Modify

```bash
# rename (title only, hpath follows)
$sy /api/filetree/renameDocByID -d '{"id":"<docID>","title":"New title"}'
# move under another document
$sy /api/filetree/moveDocsByID -d '{"fromIDs":["<id>"],"toID":"<targetDocOrNotebookID>"}'
# duplicate
$sy /api/filetree/duplicateDoc -d '{"id":"<docID>"}'
```

Structural conversions: `/api/filetree/heading2Doc`
`{srcHeadingID, targetNoteBook, targetPath, previousPath, toTop}` splits a
heading out into its own document; `/api/filetree/doc2Heading`
`{srcID, targetID, after}` folds a document back in.

## Delete — guarded

```bash
$sy /api/filetree/removeDocByID -d '{"id":"<docID>"}'      # REFUSED, prints blast radius
$sy /api/filetree/removeDocByID -d '{"id":"<docID>"}' -y   # after user confirms
```

Deleting a document deletes **all descendant documents** under it. The blast
radius report shows descendant block count and inbound reference count — relay
both to the user. Whether it lands in the workspace trash depends on the user's
SiYuan settings; do not promise recoverability.

`removeDocs` takes `{paths:[...]}` of internal paths, `removeDoc` takes
`{notebook, path}`. `removeDocByID` is the one to prefer.
