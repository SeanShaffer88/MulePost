#!/usr/bin/env python3
"""MulePost gate: Lua parse + TOC cross-check + classifier/plan
audit + money-API source audit + version consistency + harness.

The money audit is a build rule, not a style preference: MulePost
promises gold is never attached, and the promise is kept by there
being NO money-attach call anywhere in the source - and by SendMail
being callable from Send.lua only. The classifier audit pins the
safety cases (quest items never classify; grey quest items neither)
and the plan audit pins the 12-stack chunking and postage estimate.
Proves logic against a mock; live mailbox runtime stays Unverified.
"""
import pathlib
import re
import subprocess
import sys

from luaparser import ast

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "MulePost"
TOC = "MulePost_Camelot.toc"

VALIDATOR_LUA = r"""
function(ns)
  local bad = {}
  local function add(s) bad[#bad + 1] = s end
  if #ns.CATEGORIES ~= 8 then add("categories " .. #ns.CATEGORIES .. " != 8") end
  local cases = {
    { "Trade Goods", "Cloth", 1, "cloth" },
    { "Trade Goods", "Herb", 1, "herb" },
    { "Trade Goods", "Metal & Stone", 1, "ore" },
    { "Trade Goods", "Leather", 1, "leather" },
    { "Trade Goods", "Enchanting", 1, "enchanting" },
    { "Consumable", "Potion", 1, "consumable" },
    { "Miscellaneous", "Other", 0, "junk" },
    { "Weapon", "Swords", 2, "other" },
  }
  for i = 1, #cases do
    local c = cases[i]
    local got = ns.Classify(c[1], c[2], c[3])
    if got ~= c[4] then
      add("classify(" .. c[1] .. "," .. c[2] .. "," .. c[3] .. ") = " .. tostring(got) .. ", want " .. c[4])
    end
  end
  if ns.Classify("Quest", "Quest", 1) ~= nil then add("quest item classified - must be excluded") end
  if ns.Classify("Quest", "Quest", 0) ~= nil then add("grey quest item classified - must be excluded") end
  local inv = {}
  for i = 1, 13 do inv[i] = { bag = 0, slot = i, name = "C" .. i, count = 1, category = "cloth" } end
  local plan = ns.BuildPlan(inv, { { category = "cloth", recipient = "T" } })
  if #plan.mails ~= 2 then add("13 stacks produced " .. #plan.mails .. " mails, want 2")
  else
    if #plan.mails[1].stacks ~= 12 or #plan.mails[2].stacks ~= 1 then add("chunk sizes wrong") end
    if plan.mails[1].postage ~= 360 then add("postage estimate " .. plan.mails[1].postage .. " != 360") end
  end
  return bad
end
"""

FORBIDDEN = ["SetSendMailMoney", "SetSendMailCOD"]


def schema_failures():
    try:
        import lupa
    except ImportError:
        return ["lupa not available for schema validation"]
    lua = lupa.LuaRuntime()
    validate = lua.eval(VALIDATOR_LUA)
    ns = lua.table()
    chunk = lua.compile((ADDON / "Plan.lua").read_text())
    chunk("MulePost", ns)
    bad = validate(ns)
    problems = [bad[i] for i in range(1, len(bad) + 1)]
    print(f"schema: classifier + plan audit, {len(problems)} problem(s)")
    return [f"schema: {p}" for p in problems]


def main():
    failures = []
    lua_files = sorted(ADDON.glob("*.lua"))
    for path in lua_files:
        try:
            ast.parse(path.read_text())
            print(f"parse ok: {path.name}")
        except Exception as exc:
            failures.append(f"parse FAIL {path.name}: {exc}")
    lines = (ADDON / TOC).read_text().splitlines()
    listed = [ln.strip() for ln in lines if ln.strip().endswith(".lua")]
    iface = [ln for ln in lines if ln.startswith("## Interface:")]
    print(f"{TOC}: interface {iface} files {listed}")
    if iface != ["## Interface: 16001"]:
        failures.append(f"{TOC} interface is {iface}, want 16001 (Forever only)")
    for name in listed:
        if not (ADDON / name).exists():
            failures.append(f"{TOC} lists missing file {name}")
    for path in lua_files:
        if path.name not in listed:
            failures.append(f"{path.name} exists but is not in the TOC")
    for path in lua_files:
        text = path.read_text()
        if "SetBackdrop(" in text and path.name != "UI.lua":
            failures.append(f"{path.name} calls SetBackdrop outside UI.lua")
        for token in FORBIDDEN:
            if token in text:
                failures.append(f"{path.name} references {token} - gold/COD must be structurally impossible")
        if "SendMail(" in text and path.name != "Send.lua":
            failures.append(f"{path.name} calls SendMail outside Send.lua")
    ui_text = (ADDON / "UI.lua").read_text()
    if "SetBackdrop(" in ui_text and "BackdropTemplate" not in ui_text:
        failures.append("UI.lua calls SetBackdrop without BackdropTemplate")
    failures += schema_failures()
    versions = {}
    m = re.search(r"^## Version:\s*(\S+)", (ADDON / TOC).read_text(), re.M)
    versions[TOC] = m.group(1) if m else None
    m = re.search(r'ns\.VERSION = "([^"]+)"', (ADDON / "Core.lua").read_text())
    versions["Core.lua"] = m.group(1) if m else None
    m = re.search(r'^VERSION = "([^"]+)"',
                  (ROOT / "tools" / "package.py").read_text(), re.M)
    versions["package.py"] = m.group(1) if m else None
    if len(set(versions.values())) == 1 and None not in versions.values():
        print(f"version consistency: {versions['Core.lua']} in all 3 places")
    else:
        failures.append(f"version mismatch: {versions}")
    proc = subprocess.run(
        [sys.executable, str(ROOT / "tools" / "harness.py")],
        capture_output=True, text=True)
    print(proc.stdout)
    if proc.returncode != 0:
        failures.append("harness FAIL")
        print(proc.stderr)
    if failures:
        print("GATE: FAIL")
        for f in failures:
            print(" -", f)
        sys.exit(1)
    print("GATE: PASS (parse + toc + classifier/plan audit + money audit + version + harness)")


if __name__ == "__main__":
    main()
