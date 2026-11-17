#!/usr/bin/env python3
"""Adds (or updates) Chinese translations in thyme left/Localizable.xcstrings.

Edit the NEW dictionary below (English text -> Chinese), run the script, then run check_localization.py.
Multi-placeholder texts must use positional markers, e.g. "%1$lld / %2$lld".
"""
import json, pathlib

NEW = {
    "ABOUT": "关于",
    "Get a friendly nudge before things expire, so good food never goes to waste.": "食材快到期前给你一个温馨提醒，别让好食物浪费掉。",
    "Maybe later": "稍后再说",
    "Next": "下一步",
    "Page %lld of %lld": "第 %1$lld 页，共 %2$lld 页",
    "Point your camera at the date on the pack. We read it for you, so no typing.": "把相机对准包装上的日期，我们帮你读出来，不用打字。",
    "Scan the date": "扫描日期",
    "Show again": "再看一次",
    "Show the welcome tour again": "再看一次欢迎介绍",
    "Skip": "跳过",
    "Slide a food to the left and tap “Used it”. Watch your savings grow.": "把食材向左滑，点“用完了”，看着你节省的钱慢慢变多。",
    "Swipe when you're done": "吃完就左滑",
    "Turn on reminders": "开启提醒",
    "We'll remind you": "我们会提醒你",
    "Welcome tour": "欢迎介绍",
}

path = pathlib.Path(__file__).resolve().parent.parent / "thyme left" / "Localizable.xcstrings"
catalog = json.load(open(path))
for english, chinese in NEW.items():
    catalog["strings"][english] = {"extractionState": "manual", "localizations": {
        "zh-Hans": {"stringUnit": {"state": "translated", "value": chinese}}}}
catalog["strings"] = dict(sorted(catalog["strings"].items()))
json.dump(catalog, open(path, "w"), ensure_ascii=False, indent=2)
open(path, "a").write("\n")
print("added/updated", len(NEW))
