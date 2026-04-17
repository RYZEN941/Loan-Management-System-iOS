# Media API Guide (Frontend)

This document explains `media.v1.MediaService` for general file uploads using Cloudflare R2.

## Service

- gRPC service: `media.v1.MediaService`

## RPC List

- `InitiateMediaUpload`
- `CompleteMediaUpload`
- `ListMedia`

## Upload Flow

1. Call `InitiateMediaUpload`.
2. Upload file bytes directly to returned `upload_url` using HTTP `PUT`.
3. Call `CompleteMediaUpload` with the same `object_key`.
4. Backend stores metadata and returns final `file_url`.

`note` is optional in both initiate/complete requests.

## gRPC Metadata

- `authorization: Bearer <ACCESS_TOKEN>`

## 1) InitiateMediaUpload

Request example:

```json
{
  "file_name": "salary-slip-apr-2026.pdf",
  "content_type": "application/pdf",
  "size_bytes": 248932,
  "note": "April payslip"
}
```

Response example:

```json
{
  "success": true,
  "object_key": "media/6a39d4ac-8f9a-4ed0-b07c-255574f3fb16/1769000000000000000_salary-slip-apr-2026.pdf",
  "upload_url": "https://...",
  "upload_method": "PUT",
  "expires_at": "2026-04-17T14:10:00Z"
}
```

## 2) CompleteMediaUpload

Request example:

```json
{
  "object_key": "media/6a39d4ac-8f9a-4ed0-b07c-255574f3fb16/1769000000000000000_salary-slip-apr-2026.pdf",
  "file_name": "salary-slip-apr-2026.pdf",
  "content_type": "application/pdf",
  "size_bytes": 248932,
  "note": "April payslip"
}
```

Response example:

```json
{
  "success": true,
  "media_id": "26a6fdd7-caf2-4ea2-bf65-7b40cf470c9f",
  "file_url": "https://cdn.example.com/media/6a39d4ac-8f9a-4ed0-b07c-255574f3fb16/1769000000000000000_salary-slip-apr-2026.pdf",
  "uploaded_at": "2026-04-17T13:58:44Z"
}
```

## 3) ListMedia

Request example:

```json
{
  "limit": 20,
  "offset": 0
}
```

Response example:

```json
{
  "items": [
    {
      "media_id": "26a6fdd7-caf2-4ea2-bf65-7b40cf470c9f",
      "file_name": "salary-slip-apr-2026.pdf",
      "content_type": "application/pdf",
      "size_bytes": 248932,
      "file_url": "https://cdn.example.com/media/6a39d4ac-8f9a-4ed0-b07c-255574f3fb16/1769000000000000000_salary-slip-apr-2026.pdf",
      "note": "April payslip",
      "uploaded_at": "2026-04-17T13:58:44Z"
    }
  ]
}
```

## Validation Notes

- Allowed MIME types: `image/jpeg`, `image/png`, `application/pdf`.
- Max size controlled by backend config `MEDIA_MAX_UPLOAD_BYTES`.
