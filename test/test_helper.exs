# Silence warnings about recompiling migration files during tests
Code.compiler_options(ignore_module_conflict: true)

ExUnit.start(capture_log: true)
