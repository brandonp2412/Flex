#!/usr/bin/env python3
import argparse, asyncio, functools, html, http.server, json, threading, shutil, struct, tempfile
from pathlib import Path
from patchright.async_api import async_playwright
from screenshot_status_bar import STATUS_BAR_HEIGHT, capture_with_status_bar

EXPECTED_NAMES = {f"{n}_en-US.png" for n in range(1, 9)}
FULL_NAMES = {f"full-{name}.png" for name in (
    "settings-appearance", "settings-data", "settings-formats", "settings-plans",
    "settings-tabs", "settings-timers", "settings-workouts", "categories",
    "category-create", "about", "whats-new", "permissions", "database-error",
    "plan-create", "plan-exercise-settings", "exercise-create", "exercise-edit",
    "global-progress", "exercise-history", "exercise-notes", "set-edit",
    "sets-bulk-edit", "body-weight", "settings-language",
    "graph-options", "graph-merge", "graph-empty-exercise",
    "history-filters", "history-filter-reps", "history-date-picker",
    "set-create", "set-delete-confirmation", "settings-search",
    "settings-appearance-more", "settings-workouts-more", "settings-delete-confirmation",
    "plan-selection", "plan-search-empty", "graph-search-empty", "history-search-empty",
    "cardio-set-edit", "cardio-exercise-edit", "cardio-graph",
    "body-weight-graph", "body-weight-history", "timer-idle",
)}
MAX_BYTES = 8 * 1024 * 1024

PROFILES = {
    "phoneScreenshots": (450, 800, 2.4),
    "sevenInchScreenshots": (1440, 810, 4/3),
    "tenInchScreenshots": (1280, 800, 2),
    "desktop": (1600, 881, 1),
}

def validate_screenshot(path, expected):
    with path.open("rb") as source:
        header = source.read(26)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) != 26:
        raise ValueError(f"Invalid PNG: {path}")
    if struct.unpack(">II", header[16:24]) != expected:
        raise ValueError(f"Unexpected dimensions: {path}")
    if header[24:26] != bytes((8, 2)) or path.stat().st_size > MAX_BYTES:
        raise ValueError(f"Invalid RGB PNG or file size: {path}")


async def request(page, message=None):
    command = {"command": "request_data"}
    if message is not None:
        command["message"] = message
    await page.evaluate("command => { window.$flutterDriver(JSON.stringify(command)); }", command, isolated_context=False)
    await page.wait_for_function("window.$flutterDriverResult != null", timeout=90000)
    result = await page.evaluate("() => {const r = window.$flutterDriverResult; window.$flutterDriverResult = null; return r;}", isolated_context=False)
    response = json.loads(result)
    if response.get("isError"):
        raise RuntimeError(response)
    return json.loads(response["response"]["message"])

async def capture(browser, url, out, name, debug_dir, expected):
    w,h,scale = PROFILES[name]
    status_bar = name != "desktop"
    options = dict(viewport={"width":w,"height":h}, device_scale_factor=scale, reduced_motion="reduce", locale="en-US", timezone_id="UTC")
    if name == "phoneScreenshots":
        options.update(is_mobile=True, has_touch=True, user_agent="Mozilla/5.0 (Linux; Android 15; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36")
    context=await browser.new_context(**options)
    dest=out/name
    dest.mkdir(parents=True,exist_ok=True)
    page=await context.new_page()
    compositor_context = await browser.new_context(viewport={"width": round(w * scale), "height": round(h * scale)}, device_scale_factor=1) if status_bar else None
    compositor = await compositor_context.new_page() if compositor_context else None
    await page.clock.set_fixed_time("2026-11-26T23:00:00Z")
    page.on("console", lambda msg: print(name, msg.type, msg.text[:500], flush=True) if msg.type in ("error","warning") else None)
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    try:
        await page.goto(url, wait_until="domcontentloaded")
        await page.wait_for_function("typeof window.$flutterDriver === 'function'",timeout=90000)
        print(name, "viewport",await page.evaluate("() => [innerWidth,innerHeight,devicePixelRatio]"),flush=True)
        response=await request(page,"pending")
        captured = set()
        while True:
            data=response.get("data") or {}
            command=data.get("web_driver_command")
            if command=="WebDriverCommandType.screenshot":
                filename=data["screenshot_name"]+".png"
                if filename not in expected or filename in captured:
                    raise RuntimeError(f"Unexpected screenshot: {filename}")
                await page.wait_for_timeout(500)
                if compositor:
                    await capture_with_status_bar(page, compositor, dest/filename, w, h, scale, existing_inset=True)
                else:
                    await page.screenshot(path=str(dest/filename), animations="disabled", scale="device")
                validate_screenshot(dest/filename, (round(w*scale), round(h*scale)))
                captured.add(filename)
                print(name,filename,flush=True)
                response=await request(page,"complete")
            elif command=="WebDriverCommandType.ack":
                response=await request(page,"pending")
            elif command=="WebDriverCommandType.noop":
                result=await request(page)
                print(name, "RESULT", json.dumps(result), flush=True)
                if captured != expected or result.get("result") != "true" or errors:
                    raise RuntimeError(f"{name}: captured={captured}, result={result}, page errors={errors}")
                return
            else:
                raise RuntimeError(response)
    except Exception:
        shutil.copytree(dest, debug_dir / "failed" / name, dirs_exist_ok=True)
        await page.screenshot(path=str(debug_dir / f"{name}-debug.png"))
        raise
    finally:
        await context.close()
        if compositor_context:
            await compositor_context.close()

STORE_NAMES = (
    "plans", "graphs", "settings", "start-plan", "strength-graph",
    "history", "edit-plan", "rest-timer",
)

PROFILE_LABELS = {
    "phoneScreenshots": "Phone",
    "sevenInchScreenshots": "7-inch tablet",
    "tenInchScreenshots": "10-inch tablet",
    "desktop": "Desktop",
}


def build_gallery(captures, destination):
    entries = {}
    for profile in PROFILES:
        files = [
            (captures / profile / f"{number}_en-US.png", f"{number:02}-{name}.png")
            for number, name in enumerate(STORE_NAMES, 1)
        ] + [
            (captures / "full" / profile / name, name.removeprefix("full-"))
            for name in sorted(FULL_NAMES)
        ]
        w, h, scale = PROFILES[profile]
        for source, name in files:
            validate_screenshot(source, (round(w * scale), round(h * scale)))
        entries[profile] = files

    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent, prefix=".gallery-") as temp:
        gallery = Path(temp) / "gallery"
        gallery.mkdir()
        root = ["# Flex screenshot gallery", "",
                "Generated from the automated screenshot fixture with sample data.", "",
                f"{sum(map(len, entries.values()))} screenshots across {len(entries)} device profiles.", ""]
        sections = []
        for profile, files in entries.items():
            label = PROFILE_LABELS[profile]
            root.append(f"- [{label} — {len(files)} screenshots]({profile}/)")
            directory = gallery / profile
            directory.mkdir()
            markdown = [f"# {label}", "", "[All device profiles](../)", ""]
            cards = []
            for source, filename in files:
                shutil.copyfile(source, directory / filename)
                title = filename.removesuffix(".png")
                if title[:2].isdigit():
                    title = title[3:]
                title = title.replace("-", " ").capitalize()
                width = 260 if profile == "phoneScreenshots" else 480
                markdown.extend([f"### {title}", "", f'<a href="{filename}"><img src="{filename}" alt="{title}" width="{width}"/></a>', ""])
                path = f"{profile}/{filename}"
                cards.append(f'<a href="{path}"><img loading="lazy" src="{path}" alt="{html.escape(title)}"><span>{html.escape(title)}</span></a>')
            (directory / "README.md").write_text("\n".join(markdown), encoding="utf-8")
            sections.append(f'<section id="{profile}"><h2>{label} · {len(files)} screenshots</h2><div class="screens {profile}">{"".join(cards)}</div></section>')
        (gallery / "README.md").write_text("\n".join(root) + "\n", encoding="utf-8")
        links = " ".join(f'<a href="#{profile}">{label}</a>' for profile, label in PROFILE_LABELS.items())
        (gallery / "index.html").write_text(
            '<!doctype html><html lang="en"><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>Flex screenshots</title><style>'
            'body{font:16px system-ui;margin:24px;background:#17161b;color:#eee}'
            'nav{display:flex;gap:20px;flex-wrap:wrap;position:sticky;top:0;background:#17161b;padding:12px 0}'
            'a{color:#d3bfff;text-decoration:none}.screens{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:16px}'
            '.phoneScreenshots{grid-template-columns:repeat(auto-fill,minmax(200px,1fr))}'
            '.screens a{display:flex;flex-direction:column;gap:8px;background:#25242b;border-radius:12px;padding:12px}'
            'img{width:100%;height:auto;object-fit:contain;border-radius:5px}section{scroll-margin-top:65px}'
            '@media(max-width:500px){.screens,.phoneScreenshots{grid-template-columns:1fr}}'
            '</style><h1>Flex screenshots</h1><p>All device profiles · Sample data · Click any image for full resolution</p>'
            f'<nav>{links}</nav>{"".join(sections)}</html>',
            encoding="utf-8",
        )
        if destination.exists():
            shutil.rmtree(destination)
        gallery.rename(destination)


async def main(args):
    expected = FULL_NAMES if args.full else EXPECTED_NAMES
    args.output.mkdir(parents=True, exist_ok=True)
    handler=functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(args.web))
    server=http.server.ThreadingHTTPServer(("127.0.0.1",0),handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix="flex-screenshots-") as directory:
            staged = Path(directory)
            async with async_playwright() as p:
                browser = await p.chromium.launch(
                    headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"]
                )
                try:
                    for name in args.profiles:
                        url = f"http://127.0.0.1:{server.server_port}/" + ("?gallery=full" if args.full else "")
                        await capture(browser, url, staged, name, args.output, expected)
                finally:
                    await browser.close()
            for name in args.profiles:
                destination = args.output / name
                destination.mkdir(parents=True, exist_ok=True)
                for filename in sorted(expected):
                    target = args.output / "full" / name if filename in FULL_NAMES else destination
                    target.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(staged / name / filename, target / filename)
            if args.gallery:
                build_gallery(args.output, args.gallery)
    finally:
        server.shutdown()
        server.server_close()
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--gallery", type=Path, help="Build the full gallery after capture")
    parser.add_argument("--web",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("profiles",nargs="*",default=list(PROFILES))
    args = parser.parse_args()
    if args.gallery and not args.full:
        parser.error("--gallery requires --full")
    if any(name not in PROFILES for name in args.profiles):
        parser.error("Unknown screenshot profile")
    asyncio.run(main(args))
