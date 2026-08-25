#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"

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

  def test_treats_newlines_as_command_whitespace
    stdout, status = Open3.capture2(SCRIPT, "alx\nbrain")

    assert status.success?
    assert_equal "\n", stdout
  end

  def test_runs_when_bash_is_available_without_ruby
    Dir.mktmpdir do |bin_dir|
      File.symlink("/bin/bash", File.join(bin_dir, "bash"))

      stdout, stderr, status = Open3.capture3({ "PATH" => bin_dir }, SCRIPT, "nvim")

      assert status.success?, stderr
      assert_equal "󰘦\n", stdout
    end
  end
end
