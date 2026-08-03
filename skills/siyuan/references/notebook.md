# Notebooks

23 endpoints (`sy api notebook`). A notebook (`box`) is the top-level container;
its ID is the `box` column on every block.

```bash
$sy nb                                   # id + name (+ encryption state)
$sy /api/notebook/lsNotebooks -q '.notebooks[]|{id,name,closed,encrypted}'
$sy /api/notebook/createNotebook -d '{"name":"My Notebook"}'
$sy /api/notebook/renameNotebook -d '{"notebook":"<nbID>","name":"New name"}'
$sy /api/notebook/setNotebookIcon -d '{"notebook":"<nbID>","icon":"1f4d4"}'
$sy /api/notebook/openNotebook -d '{"notebook":"<nbID>"}'
$sy /api/notebook/closeNotebook -d '{"notebook":"<nbID>"}'
```

`icon` is a lowercase hex emoji codepoint (`1f4d4` = 📔), not the emoji itself.

## Closed notebooks

A closed notebook's blocks are **removed from the SQLite index**. SQL queries
return nothing for it and writes fail. Check `closed` in `lsNotebooks` before
concluding content is missing; `openNotebook` to bring it back.

## Encrypted notebooks (3.7+)

```bash
$sy /api/notebook/getEncryptedNotebookStatus
$sy /api/notebook/unlockNotebook -d '{"notebook":"<nbID>","password":"..."}'
```

While locked, the notebook is invisible to SQL and to search, and writes to it
fail. If a notebook shows `encrypted:true, unlocked:false`:

1. Tell the user it is locked and ask whether to proceed.
2. Never ask for or store the password in a file or in conversation — have the
   user unlock it in the SiYuan UI, then retry.

`changeMasterPassword` and `disableEncryptedNotebooks` are CRITICAL-guarded:
getting them wrong can make content permanently unreadable.

## Config

```bash
$sy /api/notebook/getNotebookConf -d '{"notebook":"<nbID>"}'
$sy /api/notebook/setNotebookConf -d '{"notebook":"<nbID>","conf":{...}}'
```
`setNotebookConf` replaces the whole `conf` object — read it, modify the field,
write it back. Notable fields: `dailyNoteSavePath`,
`dailyNoteTemplatePath`, `docCreateSavePath`, `sortMode`, `refCreateSavePath`.

## Delete — CRITICAL

`removeNotebook` destroys the notebook and every document in it. Refused without
`-y`; the blast radius report gives doc and block counts. Relay them verbatim
and get an unambiguous confirmation before re-running.
