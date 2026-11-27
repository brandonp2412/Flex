import base64
import struct

STATUS_BAR_HEIGHT = 24


async def capture_with_status_bar(page, compositor, path, width, height, scale, existing_inset=False):
    screenshot = await page.screenshot(animations="disabled", scale="device")
    pixel_width, pixel_height = round(width * scale), round(height * scale)
    app_width, app_height = struct.unpack(">II", screenshot[16:24])
    expected_app_height = pixel_height if existing_inset else pixel_height - STATUS_BAR_HEIGHT * scale
    if app_width != pixel_width or abs(app_height - expected_app_height) > 1:
        raise ValueError(f"Unexpected app screenshot dimensions: {app_width}x{app_height}")
    await compositor.set_content('<body style="margin:0;overflow:hidden"><canvas style="display:block"></canvas></body>')
    await compositor.evaluate("""async ({src, width, height, scale, existingInset}) => {
        const img = new Image();
        img.src = src;
        await img.decode();
        const canvas = document.querySelector('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d', {alpha: false});
        const barHeight = existingInset ? Math.round(24 * scale) : height - img.naturalHeight;
        const sample = document.createElement('canvas');
        sample.width = sample.height = 1;
        const sampleCtx = sample.getContext('2d');
        sampleCtx.drawImage(img, 0, existingInset ? barHeight - 1 : 0, img.naturalWidth, 1, 0, 0, 1, 1);
        const [r, g, b] = sampleCtx.getImageData(0, 0, 1, 1).data;
        ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
        ctx.drawImage(img, 0, existingInset ? 0 : barHeight);
        ctx.fillRect(0, 0, width, barHeight);
        ctx.save();
        ctx.scale(scale, scale);
        ctx.translate(0, (barHeight / scale - 24) / 2);
        ctx.fillStyle = (r * .299 + g * .587 + b * .114) > 150
            ? '#202124' : '#f1f3f4';
        ctx.font = '500 14px Arial, sans-serif';
        ctx.textBaseline = 'middle';
        ctx.fillText('9:41', 16, 12);
        const right = width / scale - 16;
        const percentWidth = ctx.measureText('100%').width;
        const batteryX = right - percentWidth - 4 - 10;
        ctx.fillText('100%', right - percentWidth, 12);
        ctx.save();
        ctx.translate(batteryX, 4.5);
        ctx.beginPath();
        ctx.roundRect(3, 0, 4, 2, .5);
        ctx.roundRect(1, 2, 8, 13, 1.5);
        ctx.fill();
        ctx.restore();
        ctx.save();
        ctx.translate(batteryX - 19, 4.5);
        ctx.fill(new Path2D('M1 14 14 1v13Z'));
        ctx.restore();
        ctx.save();
        ctx.translate(batteryX - 39, 4);
        ctx.fill(new Path2D('M0 5a12 12 0 0 1 16 0L8 15Z'));
        ctx.restore();
        ctx.restore();
    }""", {"src": "data:image/png;base64," + base64.b64encode(screenshot).decode(),
           "width": pixel_width, "height": pixel_height, "scale": scale, "existingInset": existing_inset}, isolated_context=False)
    await compositor.screenshot(path=str(path), animations="disabled", scale="device")

