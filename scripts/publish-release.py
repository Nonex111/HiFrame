#!/usr/bin/env python3
"""Publish a tagged HiFrame build only after uploaded assets are verified."""

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def gh(*args: str) -> str:
    return subprocess.check_output(['gh', *args], text=True).strip()


def version(tag: str) -> tuple[int, ...]:
    if not re.fullmatch(r'v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)', tag):
        raise ValueError(f'Invalid version tag: {tag}')
    return tuple(map(int, tag[1:].split('.')))


def publish(tag: str) -> None:
    requested = version(tag)
    releases = json.loads(gh('release', 'list', '--limit', '100', '--json', 'tagName,isDraft,isLatest'))
    existing = next((item for item in releases if item['tagName'] == tag), None)
    latest = next((item for item in releases if item['isLatest']), None)
    if existing and not existing['isDraft']:
        raise RuntimeError('This release is already published; published assets are never overwritten.')
    if latest and requested <= version(latest['tagName']):
        raise RuntimeError('The new release must be newer than the current Latest release.')

    assets = [Path('downloads/HiFrame.zip'), Path('downloads/HiFrame.zip.sha256')]
    for asset in assets:
        if not asset.is_file():
            raise FileNotFoundError(asset)
    digest = hashlib.sha256(assets[0].read_bytes()).hexdigest()
    if assets[1].read_text().strip() != f'{digest}  HiFrame.zip':
        raise RuntimeError('Local archive checksum mismatch')

    with tempfile.TemporaryDirectory(prefix='hiframe-release-') as directory:
        temporary = Path(directory)
        notes = temporary / 'notes.md'
        notes.write_text(
            f'## 中文\n\n'
            f'下载 **HiFrame.zip**，解压后将 **HiFrame.app** 放入“应用程序”文件夹，再打开应用。'
            f'支持 Apple Silicon Mac，要求 macOS 13 或更高版本。\n\n'
            f'HiFrame 通过持续的微小画面变化请求高帧率，不保证帧率恒定或锁定面板刷新率。'
            f'此预览版使用临时签名，尚未经过 Apple 公证。\n\n'
            f'## English\n\n'
            f'Download **HiFrame.zip**, unzip it, move **HiFrame.app** to Applications, and open it. '
            f'Requires an Apple Silicon Mac running macOS 13 or later.\n\n'
            f'HiFrame requests a high presentation rate through tiny continuous visual changes; '
            f'it does not guarantee a constant frame rate or lock the panel refresh rate. '
            f'This preview is ad-hoc signed and not notarized.\n\n'
            f'**SHA-256:** `{digest}`\n', encoding='utf-8')
        if not existing:
            gh('release', 'create', tag, '--verify-tag', '--draft',
               '--title', f'HiFrame {tag[1:]} / macOS 下载', '--notes-file', str(notes))
        else:
            gh('release', 'edit', tag, '--notes-file', str(notes))
        gh('release', 'upload', tag, *(str(asset) for asset in assets), '--clobber')
        downloaded = temporary / 'downloaded'
        gh('release', 'download', tag, '--dir', str(downloaded), '--pattern', 'HiFrame.zip*')
        for asset in assets:
            if (downloaded / asset.name).read_bytes() != asset.read_bytes():
                raise RuntimeError(f'Uploaded asset mismatch: {asset.name}; release remains a draft.')
        # Only a fully uploaded and verified release becomes public and Latest.
        gh('release', 'edit', tag, '--draft=false', '--latest')
        url = gh('release', 'view', tag, '--json', 'url', '--jq', '.url')
        print(url)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
                summary.write(f'Published / 已发布 [{tag}]({url})\n\nSHA-256: `{digest}`\n')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: publish-release.py v1.2.3')
    publish(sys.argv[1])
