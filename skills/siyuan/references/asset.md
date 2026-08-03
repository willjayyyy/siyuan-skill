# Assets (images and attachments)

20 endpoints (`sy api asset`). Assets live under `assets/` in the workspace and
are referenced from markdown as `![alt](assets/name-20260803120000-abc1234.png)`.

## Upload

`/api/asset/upload` is the one endpoint that is **not** JSON — it is
`multipart/form-data`, so `sy` cannot wrap it. Use curl directly:

```bash
. ~/.config/siyuan/env
curl -s -X POST "$SIYUAN_URL/api/asset/upload" \
  -H "Authorization: Token $SIYUAN_TOKEN" \
  -F "assetsDirPath=/assets/" \
  -F "file[]=@/path/to/image.png" | jq '.data'
```

Response: `{errFiles:[], succMap:{"image.png":"assets/image-2026...-abc.png"}}`.
Take the value from `succMap` and embed it in markdown as
`![caption](assets/image-2026...-abc.png)`.

`assetsDirPath` of `/assets/` is workspace-global; per-document assets use
`/<notebookID>/<docPath>/assets/`.

## Insert local files without uploading

```bash
$sy /api/asset/insertLocalAssets -d '{"id":"<docID>","assetPaths":["/abs/path.png"],"isUpload":true}'
```
Copies the local file into the workspace and returns the asset path. Requires
the kernel to have filesystem access to that path — true for a local instance,
**not** for a remote one like a self-hosted server.

## Inspect and clean

```bash
$sy /api/asset/getDocAssets -d '{"id":"<docID>"}'
$sy /api/asset/statAsset -d '{"path":"assets/x.png"}'
$sy /api/asset/resolveAssetPath -d '{"path":"assets/x.png"}'
$sy /api/asset/getUnusedAssets
$sy /api/asset/removeUnusedAssets -y      # guarded
```

Or via SQL: `SELECT path,name,docpath FROM assets WHERE root_id='<docID>'`

## OCR

`/api/asset/ocr {path}` runs OCR on an image; `/api/asset/getImageOCRText
{path}` reads the cached result. Only works if the user enabled OCR in settings.

## Trap

When archiving content that references local images, upload the images **first**,
then substitute the returned `assets/...` paths into the markdown before calling
`newdoc`. A document created with `file://` or absolute local paths will render
as broken images on every other device.
