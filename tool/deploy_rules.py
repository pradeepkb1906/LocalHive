#!/usr/bin/env python3
"""Deploys firestore.rules to the project using the service account
(.secrets/service_account.json). Prints only status — never credentials."""
import json
import os

import google.auth.transport.requests
from google.oauth2 import service_account
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SA = os.path.join(ROOT, ".secrets", "service_account.json")
RULES = os.path.join(ROOT, "firestore.rules")
PROJECT = "localhivelocalhive"

creds = service_account.Credentials.from_service_account_file(
    SA, scopes=["https://www.googleapis.com/auth/firebase"])
creds.refresh(google.auth.transport.requests.Request())
H = {"Authorization": f"Bearer {creds.token}"}

source = {"source": {"files": [
    {"name": "firestore.rules", "content": open(RULES).read()}]}}

r = requests.post(
    f"https://firebaserules.googleapis.com/v1/projects/{PROJECT}/rulesets",
    headers=H, json=source)
r.raise_for_status()
ruleset = r.json()["name"]
print(f"ruleset created: {ruleset.split('/')[-1]}")

release = f"projects/{PROJECT}/releases/cloud.firestore"
r = requests.patch(
    f"https://firebaserules.googleapis.com/v1/{release}",
    headers=H,
    json={"release": {"name": release, "rulesetName": ruleset}})
if r.status_code == 404:
    r = requests.post(
        f"https://firebaserules.googleapis.com/v1/projects/{PROJECT}/releases",
        headers=H, json={"name": release, "rulesetName": ruleset})
r.raise_for_status()
print("release updated: cloud.firestore now enforces firestore.rules")
