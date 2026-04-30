#!/usr/bin/env python3
"""Inject lightweight Sentry Browser SDK monitoring into exported Web HTML."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


DEFAULT_HTML = Path("build/web/index.html")
DEFAULT_SENTRY_BROWSER_CDN = "https://browser.sentry-cdn.com/8.55.0/bundle.min.js"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", type=Path, default=DEFAULT_HTML)
    parser.add_argument("--dsn", required=True)
    parser.add_argument("--release", default="")
    parser.add_argument("--environment", default="production")
    parser.add_argument("--cdn", default=DEFAULT_SENTRY_BROWSER_CDN)
    return parser.parse_args()


def build_head_script(args: argparse.Namespace) -> str:
    config = {
        "dsn": args.dsn.strip(),
        "release": args.release.strip(),
        "environment": args.environment.strip() or "production",
    }
    config_json = json.dumps(config, ensure_ascii=False, sort_keys=True)
    return f"""<!-- WWL Adventure browser monitoring -->
<script src="{args.cdn}" crossorigin="anonymous"></script>
<script>
window.WWL_SENTRY_CONFIG = {config_json};
(function () {{
\tconst config = window.WWL_SENTRY_CONFIG || {{}};
\tif (!config.dsn || !window.Sentry) {{
\t\treturn;
\t}}
\tSentry.init({{
\t\tdsn: config.dsn,
\t\trelease: config.release || undefined,
\t\tenvironment: config.environment || 'production',
\t\tsendDefaultPii: false,
\t\ttracesSampleRate: 0.0,
\t}});
\tSentry.setTags({{
\t\tgame: 'WWL Adventure',
\t\tplatform: 'web',
\t\tbuild_target: 'web',
\t}});
\tconst reportedGodotErrors = new Map();
\tfunction shouldCaptureGodotError(text) {{
\t\tif (
\t\t\ttext.indexOf('still waiting on run dependencies') === 0 ||
\t\t\ttext.indexOf('dependency:') === 0 ||
\t\t\ttext === '(end of list)' ||
\t\t\ttext.indexOf('   at:') === 0 ||
\t\t\ttext.indexOf('    GDScript backtrace') === 0 ||
\t\t\t/^\\s*\\[\\d+\\]/.test(text)
\t\t) {{
\t\t\treturn false;
\t\t}}
\t\treturn text.indexOf('ERROR:') === 0 || text.indexOf('SCRIPT ERROR:') === 0;
\t}}
\twindow.WWL_REPORT_GODOT_LOG = function (message) {{
\t\tSentry.addBreadcrumb({{
\t\t\tcategory: 'godot',
\t\t\tlevel: 'info',
\t\t\tmessage: String(message).slice(0, 1024),
\t\t}});
\t}};
\twindow.WWL_REPORT_GODOT_ERROR = function (message) {{
\t\tconst text = String(message);
\t\tSentry.addBreadcrumb({{
\t\t\tcategory: 'godot',
\t\t\tlevel: 'error',
\t\t\tmessage: text.slice(0, 1024),
\t\t}});
\t\tif (!shouldCaptureGodotError(text)) {{
\t\t\treturn;
\t\t}}
\t\tconst key = text.slice(0, 512);
\t\tconst now = Date.now();
\t\tif ((reportedGodotErrors.get(key) || 0) + 10000 > now) {{
\t\t\treturn;
\t\t}}
\t\treportedGodotErrors.set(key, now);
\t\tSentry.withScope(function (scope) {{
\t\t\tscope.setLevel('error');
\t\t\tscope.setTag('source', 'godot_print_error');
\t\t\tscope.setContext('godot', {{ message: text.slice(0, 4096) }});
\t\t\tSentry.captureMessage('Godot error: ' + text.slice(0, 512));
\t\t}});
\t}};
}}());
</script>"""


def inject_head_script(html: str, script: str) -> str:
    marker = "<!-- WWL Adventure browser monitoring -->"
    if marker in html:
        return re.sub(
            r"<!-- WWL Adventure browser monitoring -->\s*"
            r'<script src="[^"]+" crossorigin="anonymous"></script>\s*'
            r"<script>.*?</script>",
            lambda _match: script,
            html,
            count=1,
            flags=re.DOTALL,
        )
    closing_head = "\n\t</head>"
    if closing_head not in html:
        raise ValueError("Could not find </head> insertion point in exported HTML")
    return html.replace(closing_head, f"\n{script}{closing_head}", 1)


def remove_godot_sentry_addon_html(html: str) -> str:
    html = re.sub(
        r"\n?<!-- Automatically added by Sentry SDK -->\s*"
        r'<script src="sentry-bundle\.js" crossorigin="anonymous"></script>\s*',
        "\n",
        html,
        count=1,
    )
    return re.sub(r'("gdextensionLibs"\s*:\s*)\[[^\]]*\]', r"\1[]", html, count=1)


def inject_godot_callbacks(html: str) -> str:
    marker = "'onPrintError': function (message) {"
    if marker in html:
        return html

    start_game_options = "engine.startGame({\n\t\t\t'onProgress': function"
    replacement = """engine.startGame({
\t\t\t'onPrint': function (message) {
\t\t\t\tconsole.log(message);
\t\t\t\tif (window.WWL_REPORT_GODOT_LOG) {
\t\t\t\t\twindow.WWL_REPORT_GODOT_LOG(message);
\t\t\t\t}
\t\t\t},
\t\t\t'onPrintError': function (message) {
\t\t\t\tconsole.error(message);
\t\t\t\tif (window.WWL_REPORT_GODOT_ERROR) {
\t\t\t\t\twindow.WWL_REPORT_GODOT_ERROR(message);
\t\t\t\t}
\t\t\t},
\t\t\t'onProgress': function"""
    if start_game_options not in html:
        raise ValueError("Could not find engine.startGame options in exported HTML")
    return html.replace(start_game_options, replacement, 1)


def main() -> int:
    args = parse_args()
    if not args.dsn.strip():
        raise ValueError("--dsn must not be empty")
    html = args.html.read_text(encoding="utf-8")
    html = remove_godot_sentry_addon_html(html)
    html = inject_head_script(html, build_head_script(args))
    html = inject_godot_callbacks(html)
    args.html.write_text(html, encoding="utf-8")
    for pattern in ("sentry-bundle.js", "sentry-bundle.js.map", "libsentry.web*.wasm"):
        for generated_file in args.html.parent.glob(pattern):
            generated_file.unlink()
    print(f"Configured Sentry Browser monitoring in {args.html}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
