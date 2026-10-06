#!/usr/bin/env python3
"""Inject a bounded W3C touch into an explicitly verified foreground app.

A successful WDA response proves injection only. Verify the resulting UI or
playback clock separately; do not treat it as a performance or function PASS.
Coordinates are UIKit points from the current device, never screenshot pixels.
"""
import argparse
import json
import time
import urllib.error
import urllib.request


def request(base, path, body=None):
    payload = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(base + path, data=payload,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as response:
        result = json.load(response)
    value = result.get("value")
    if isinstance(value, dict) and value.get("error"):
        raise RuntimeError(value["error"] + ": " + value.get("message", ""))
    if result.get("status", 0) != 0:
        raise RuntimeError("WDA rejected command")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("x", type=float)
    parser.add_argument("y", type=float)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--port", type=int, default=8102)
    parser.add_argument("--session-id")
    args = parser.parse_args()
    base = "http://127.0.0.1:" + str(args.port)
    status = request(base, "/status")
    if not status["value"].get("ready"):
        raise RuntimeError("WDA is not ready; do not inject touch")
    sid = args.session_id or status.get("sessionId")
    if not sid:
        raise RuntimeError("Existing UI session required; no Runner restart attempted")
    session = base + "/session/" + sid
    active = request(session, "/wda/activeAppInfo")["value"]
    if active.get("bundleId") != args.bundle_id:
        raise RuntimeError("Foreground app differs from requested bundle")
    # Read fresh application bounds instead of using another app/device's size.
    element = request(session, "/element", {
        "using": "xpath", "value": "//XCUIElementTypeApplication"})["value"]
    eid = element.get("ELEMENT") or element["element-6066-11e4-a52e-4f735466cecf"]
    rect = request(session, "/element/" + eid + "/rect")["value"]
    if not (rect["x"] <= args.x < rect["x"] + rect["width"] and
            rect["y"] <= args.y < rect["y"] + rect["height"]):
        raise RuntimeError("Touch lies outside current application bounds")
    started = time.time()
    request(session, "/actions", {"actions": [{
        "type": "pointer", "id": "finger", "parameters": {"pointerType": "touch"},
        "actions": [
            {"type": "pointerMove", "duration": 0, "x": args.x, "y": args.y,
             "origin": "viewport"},
            {"type": "pointerDown", "button": 0},
            {"type": "pause", "duration": 100},
            {"type": "pointerUp", "button": 0}]}]})
    print(json.dumps({"method": "W3C touch", "bundleId": args.bundle_id,
                      "point": [args.x, args.y], "applicationBounds": rect,
                      "requestStart": started, "requestEnd": time.time(),
                      "effectVerdict": "UNVERIFIED; inspect actual frame/clock"}))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, urllib.error.URLError) as error:
        raise SystemExit(str(error))
