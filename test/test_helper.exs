# Keep test output focused on assertions, not the search telemetry debug logs.
Logger.configure(level: :warning)

ExUnit.start()
