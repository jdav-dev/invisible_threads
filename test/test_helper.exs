ExUnit.start(capture_log: true)

ExUnit.after_suite(fn _suite_result ->
  data_dir = InvisibleThreads.Accounts.data_dir()

  data_dir
  |> Path.join("*.etf")
  |> Path.wildcard()
  |> Enum.each(&File.rm!/1)
end)
