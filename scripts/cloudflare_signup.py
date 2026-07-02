#!/usr/bin/env python3
import os, sys, json, time, re, getpass
from cloakbrowser import launch

CREDS_FILE = os.path.expanduser('~/workspace/credentials/cloudflare.json')

print('Cloudflare signup via CloakBrowser')
email = input('Email: ').strip()
password = getpass.getpass('Password: ').strip()

print('Launching CloakBrowser...')
browser = launch(headless=False, humanize=True, display=':1')
page = browser.new_page()

try:
    print('Opening signup page...')
    page.goto('https://dash.cloudflare.com/sign-up', wait_until='networkidle')
    time.sleep(5)

    print('Filling email...')
    page.fill('input[type="email"]', email, timeout=20000)
    time.sleep(0.8)

    print('Filling password...')
    page.fill('input[type="password"]', password, timeout=20000)
    time.sleep(0.8)

    print('Clicking Create Account...')
    page.click('button:has-text("Create Account")', timeout=20000)

    print('Waiting for post-submit navigation/verification...')
    time.sleep(10)

    url = page.url
    print('URL after submit:', url)

    os.makedirs(os.path.dirname(CREDS_FILE), exist_ok=True)
    with open(CREDS_FILE, 'w') as f:
        json.dump({'email': email, 'password': password, 'final_url': url}, f, indent=2)
    print('Saved:', CREDS_FILE)

    input('Press Enter when done/verified (browser stays open)...')
finally:
    browser.close()
