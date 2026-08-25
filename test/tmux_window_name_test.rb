#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "open3"

class TmuxWindowNameTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/tmux_window_name", __dir__)

  def test_names_claude_windows_with_claude_icon
    stdout, status = Open3.capture2(SCRIPT, "claude")

    assert status.success?
    assert_equal "\n", stdout
  end

  def test_names_opencode_windows_with_opencode_icon
    stdout, status = Open3.capture2(SCRIPT, "opencode")

    assert status.success?
    assert_equal "󰨔\n", stdout
  end
end
