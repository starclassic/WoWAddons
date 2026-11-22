# SCSeal regression checks

Install the Python test dependency with `python -m pip install -r tests/requirements.txt`,
then run `python tests/test_scseal.py` from the repository root.

The harness runs the addon in Lua 5.1 with a mocked WoW client. It checks the native
duration binding, stack-number and next-seal formatters, combat restrictions,
seal switching and old-Echo suppression, damage-proc and secret-ID rejection,
Ctrl-drag positioning, preview, settings, and missing-API behavior.

These checks do not render the native WoW UI or replace in-game verification.
