from pathlib import Path
from typing import AsyncGenerator
from playwright.async_api import BrowserContext, ViewportSize, async_playwright
from contextlib import asynccontextmanager


@asynccontextmanager
async def chrome_browser(user_data_dir: Path) -> AsyncGenerator[BrowserContext, None]:
    pw, browser = None, None
    try:
        pw = await async_playwright().start()
        browser = await pw.chromium.launch_persistent_context(
            headless=False,
            channel="chrome",
            user_data_dir=user_data_dir,
            ignore_default_args=True,
            args=[
                "--disable-dev-shm-usage",
                "--remote-debugging-pipe",
                f"--user-data-dir={user_data_dir.resolve()}",
                "about:blank",
            ],
            no_viewport=True,
        )
        await browser.add_init_script(
            """
            Object.defineProperty(navigator, "webdriver", {get: () => undefined});
            """
        )
        yield browser
    finally:
        if browser:
            await browser.close()
        if pw:
            await pw.stop()
