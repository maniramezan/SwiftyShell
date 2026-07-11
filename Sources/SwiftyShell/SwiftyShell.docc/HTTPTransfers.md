# HTTP Transfers with Curl

Build focused HTTP requests without composing shell strings.

## Overview

``Curl`` models one curl transfer at a time, including its URL, ``CurlHTTPMethod``, headers,
request body or upload file, redirects, retries, timeouts, failure behavior, and output file.
Every invocation starts with `--disable`, preventing a local `.curlrc` from silently changing the
request. Transfers also reject credentials embedded in URLs, and `--no-progress-meter` keeps
captured stderr suitable for automation.

```swift
let output = try await Curl("https://api.example.com/items")
    .method(.post)
    .header(name: "Content-Type", value: "application/json")
    .body(#"{"name":"example"}"#)
    .followRedirects()
    .retry(2)
    .requestTimeout(30)
    .failWithBody()
    .run()
```

Use ``Curl/bodyFile(_:)`` for exact file content and ``Curl/uploadFile(_:)`` for curl's upload transfer
mode. These operations are intentionally mutually exclusive; the last one selected wins.

```swift
try await Curl("https://uploads.example.com/archive")
    .method(.put)
    .uploadFile("archive.zip")
    .outputFile("receipt.json")
    .run()
```

## Protect credentials

Arguments can be visible to local process inspection and may appear if callers log a built
``Command``. Do not put authorization values, cookies, tokens, or passwords in
``Curl/header(name:value:)`` or ``Curl/body(_:)``. Store sensitive headers in a
permission-restricted file and pass only its path:

```swift
// /run/secrets/api-headers contains an Authorization header and is not logged.
let output = try await Curl("https://api.example.com/private")
    .headerFile("/run/secrets/api-headers")
    .failWithBody()
    .run()
```

Avoid curl verbose or trace options around authenticated requests because curl can print request
headers. ``Curl`` deliberately has no credential-specific or raw-argument API.

## Timeout layers

``Curl/requestTimeout(_:)`` and ``Curl/connectionTimeout(_:)`` configure curl's transfer timers. The
inherited ``ToolConfigurableCommandFamily/timeout(_:)`` configures SwiftyShell's process-level
deadline. A process timeout can provide an outer bound around curl's own retry and transfer timing.

``Curl`` returns ``ShellOutput`` rather than a structured HTTP response. Response bodies can be
arbitrary binary data, and mixing `--write-out` metadata into the same stream does not provide a
reliable collision-free format. Use ``Curl/outputFile(_:)`` when the body is binary or large.

## Topics

### Request

- ``Curl``
- ``CurlHTTPMethod``
- ``Curl/url(_:)``
- ``Curl/method(_:)``
- ``Curl/header(name:value:)``
- ``Curl/headerFile(_:)``

### Body and upload

- ``Curl/body(_:)``
- ``Curl/bodyFile(_:)``
- ``Curl/uploadFile(_:)``

### Reliability

- ``Curl/followRedirects(_:)``
- ``Curl/maximumRedirects(_:)``
- ``Curl/retry(_:)``
- ``Curl/retryDelay(_:)``
- ``Curl/retryMaximumTime(_:)``
- ``Curl/retryAllErrors(_:)``
- ``Curl/retryConnectionRefused(_:)``
- ``Curl/requestTimeout(_:)``
- ``Curl/connectionTimeout(_:)``
- ``Curl/failWithBody(_:)``

### Output

- ``Curl/outputFile(_:)``
- ``ShellOutput``
- ``OutputDestination``
