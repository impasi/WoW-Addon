#!/usr/bin/env python3
"""Runs the GymChallenge logic tests in a Lua 5.1 runtime (pip install lupa)."""
import os
import sys

from lupa import lua51

here = os.path.dirname(os.path.abspath(__file__))
addon = os.path.join(os.path.dirname(here), "GymChallenge")

lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.globals().ADDON_DIR = addon
lua.execute(open(os.path.join(here, "mock_wow.lua"), encoding="utf-8").read())
failed = lua.execute(open(os.path.join(here, "test_addon.lua"), encoding="utf-8").read())
sys.exit(1 if failed else 0)
