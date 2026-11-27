#!/usr/bin/env python3
import argparse, asyncio, functools, http.server, json, threading, shutil, struct, tempfile
from pathlib import Path
from patchright.async_api import async_playwright

EXPECTED_NAMES = {f"{n}_en-US.png" for n in range(1, 9)}
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

async def capture(browser, url, out, name, debug_dir):
    w,h,scale = PROFILES[name]
    options = dict(viewport={"width":w,"height":h}, device_scale_factor=scale, reduced_motion="reduce", locale="en-US", timezone_id="UTC")
    if name == "phoneScreenshots":
        options.update(is_mobile=True, has_touch=True, user_agent="Mozilla/5.0 (Linux; Android 15; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36")
    context=await browser.new_context(**options)
    dest=out/name
    dest.mkdir(parents=True,exist_ok=True)
    page=await context.new_page()
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
                if filename not in EXPECTED_NAMES or filename in captured:
                    raise RuntimeError(f"Unexpected screenshot: {filename}")
                await page.wait_for_timeout(500)
                await page.screenshot(path=str(dest/filename), animations="disabled", scale="device")
                validate_screenshot(dest/filename, (round(w*scale), round(h*scale)))
                captured.add(filename)
                print(name,filename,flush=True)
                response=await request(page,"complete")
            elif command=="WebDriverCommandType.ack":
                response=await request(page,"pending")
            elif command=="WebDriverCommandType.noop":
                result=await request(page)
                print(name,"RESULT",json.dumps(result)[:5000],flush=True)
                if captured != EXPECTED_NAMES or result.get("result") != "true" or errors:
                    raise RuntimeError(f"{name}: captured={captured}, result={result}, page errors={errors}")
                return
            else:
                raise RuntimeError(response)
    except Exception:
        await page.screenshot(path=str(debug_dir / f"{name}-debug.png"))
        raise
    finally:
        await context.close()

async def main(args):
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
                        await capture(browser, f"http://127.0.0.1:{server.server_port}/", staged, name, args.output)
                finally:
                    await browser.close()
            for name in args.profiles:
                destination = args.output / name
                destination.mkdir(parents=True, exist_ok=True)
                for filename in sorted(EXPECTED_NAMES):
                    shutil.copyfile(staged / name / filename, destination / filename)
    finally:
        server.shutdown()
        server.server_close()
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--web",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("profiles",nargs="*",default=list(PROFILES))
    args = parser.parse_args()
    if any(name not in PROFILES for name in args.profiles):
        parser.error("Unknown screenshot profile")
    asyncio.run(main(args))
