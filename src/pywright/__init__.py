import asyncio
from pathlib import Path

from pywright.browser import chrome_browser


async def main_async() -> None:
    async with chrome_browser(Path(".user_data")) as browser:
        page = browser.pages[0]
        await page.goto("https://www.google.com")
        await page.wait_for_timeout(10000)


def main() -> None:
    asyncio.run(main_async())
