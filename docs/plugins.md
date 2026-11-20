# SuperDock plugins

Decision (SUPERDOCK.md §12 #6): plugins are **declarative JSON**. A plugin says which URL to fetch and which parts of the JSON response to show, using a built-in tile template. No plugin code runs inside SuperDock. That means a plugin can't crash the app, read files, or reach anything other than the `https` URL it declares, and plugins are safe to share through a gallery.

Out of scope for this format: custom drawing, and interaction beyond opening a link. If a widget needs those, it belongs in the app as a native widget.

## Where plugins live

| | Location |
|---|---|
| Built-in | `SuperDock/Resources/Plugins/plugin-*.json`, shipped inside the app |
| Yours | `~/Library/Application Support/SuperDock/Plugins/*.json` (Settings → Plugins → Open Plugins Folder) |
| Community gallery | `gallery/index.json` in this repo; Settings → Plugins → Browse Gallery installs from it |

Settings → Plugins → Reload picks up edits. A file that doesn't load is listed with the reason.

## Format

```json
{
  "id": "community.github-stars",
  "name": "GitHub Stars",
  "description": "Stars for a repository.",
  "author": "you",
  "symbol": "star",
  "category": "dev",
  "sizes": ["compact", "medium"],
  "source": {
    "url": "https://api.github.com/repos/{repo}",
    "every": 1800,
    "headers": { "Accept": "application/vnd.github+json" }
  },
  "settings": [
    { "key": "repo", "label": "Repository (owner/name)", "default": "swiftlang/swift" }
  ],
  "tile": {
    "template": "value",
    "label": "★ {repo}",
    "value": "$.stargazers_count",
    "format": "number",
    "open": "https://github.com/{repo}"
  }
}
```

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Unique. Use `community.<name>`. Built-ins use `builtin.` and take precedence. |
| `name` | yes | Shown in the widget picker. |
| `symbol` | | SF Symbol name for the picker. |
| `category` | | `news`, `finance`, `fun`, `dev`, `productivity`, … (otherwise "Community Plugins"). |
| `sizes` | | Any of `compact`, `medium`, `wide`, `large`. Default compact + medium. |
| `source.url` | yes | Must be `https://`. `{key}` is replaced by that setting's value, URL-encoded. |
| `source.every` | | Seconds between fetches, minimum 60 (default 600). |
| `source.headers` | | Extra request headers. |
| `settings` | | Text fields shown in Widget Settings; each value is available as `{key}`. |
| `tile.template` | yes | `value`, `text`, `list` or `gauge` (below). |
| `tile.value` | value/text/gauge | JSONPath to the value. `{key}` placeholders are allowed. |
| `tile.subtitle` | | JSONPath to a second line (`value` template). |
| `tile.items`, `tile.links` | list | JSONPaths with `[*]` for titles and their URLs. |
| `tile.counts` | | JSONPath with `[*]` for a number shown before each list item (points, score), e.g. `$.hits[*].points`. Matched to `tile.items` by position. |
| `tile.max` | | Gauge maximum (default 100). |
| `tile.format` | | `text`, `number`, `percent` (value is 0–100), `bytes`, `currency` (with `tile.currency`, e.g. `"EUR"`). |
| `tile.prefix`, `tile.suffix`, `tile.label` | | Extra text around the value, and the label. |
| `tile.open` | | `http(s)` URL opened when the tile is clicked. |

### Templates

- **value**: label over one big formatted value, with an optional subtitle.
- **text**: a short paragraph (quotes, facts).
- **list**: the first 2–3 titles, each opening its link, with its count in front when `tile.counts` is set.
- **gauge**: a ring showing `value` out of `max`.

### JSONPath subset

`$` is the root. `.key` and `["key"]` select a field, `[0]` an array element, and `[*]` every element. Examples: `$.bitcoin.usd`, `$[0].q`, `$.hits[*].title`, `$.rates.{to}`.

## Behaviour

- **When fetching happens:** only while a tile using the plugin is on the bar (hard rule 4). Responses are cached and shared between tiles, so the bar hiding and reappearing with the Dock doesn't refetch early.
- **Failures:** a failed fetch shows a cloud-warning icon and retries at the next interval.
- **Validation:** an `id`, a `name`, an `https` URL, and the template's required path are all required, or the plugin isn't loaded.
- **Submitting to the gallery:** open a pull request adding your file under `gallery/plugins/` and an entry in `gallery/index.json`.
