#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

class StowConfigsTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/stow_configs", __dir__)

  def test_links_agent_and_demux_configs_into_a_fresh_home
    Dir.mktmpdir do |home|
      _stdout, stderr, status = Open3.capture3("/bin/bash", SCRIPT, home)

      assert status.success?, stderr
      assert_linked_to home, ".config/demux/demux.toml", "demux/.config/demux/demux.toml"
      assert_linked_to home, ".claude/settings.json", "agents/.claude/settings.json"
      assert_linked_to home, ".config/opencode/opencode.jsonc", "agents/.config/opencode/opencode.jsonc"
      assert_linked_to home, ".config/opencode/plugin/demux-notifications.ts", "agents/.config/opencode/plugin/demux-notifications.ts"
      assert_linked_to home, ".config/opencode/lib/demux-hooks.ts", "agents/.config/opencode/lib/demux-hooks.ts"
      assert_linked_to home, ".config/opencode/AGENTS.md", "agents/.config/opencode/AGENTS.md"
    end
  end

  def test_migrates_matching_agent_files_and_the_old_opencode_link
    Dir.mktmpdir do |home|
      install_existing_file home, ".claude/settings.json", "agents/.claude/settings.json"
      install_existing_file home, ".config/opencode/opencode.jsonc", "agents/.config/opencode/opencode.jsonc"
      install_existing_file home, ".config/opencode/plugin/demux-notifications.ts", "agents/.config/opencode/plugin/demux-notifications.ts"
      install_existing_file home, ".config/opencode/lib/demux-hooks.ts", "agents/.config/opencode/lib/demux-hooks.ts"
      install_existing_file home, ".config/demux/demux.toml", "demux/.config/demux/demux.toml"
      install_existing_file home, ".config/demux/sessions.toml", "demux/.config/demux/sessions.toml"

      old_tui = File.join(home, ".config/opencode/tui.json")
      File.symlink(File.expand_path("../opencode/.config/opencode/tui.json", __dir__), old_tui)

      _stdout, stderr, status = Open3.capture3("/bin/bash", SCRIPT, home)

      assert status.success?, stderr
      assert_linked_to home, ".claude/settings.json", "agents/.claude/settings.json"
      assert_linked_to home, ".config/opencode/opencode.jsonc", "agents/.config/opencode/opencode.jsonc"
      assert_linked_to home, ".config/opencode/tui.json", "agents/.config/opencode/tui.json"
      assert_linked_to home, ".config/demux/demux.toml", "demux/.config/demux/demux.toml"
    end
  end

  private

  def install_existing_file(home, destination, source)
    path = File.join(home, destination)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.cp(File.expand_path("../#{source}", __dir__), path)
  end

  def assert_linked_to(home, destination, source)
    link = File.join(home, destination)
    expected = File.expand_path("../#{source}", __dir__)

    assert File.exist?(link), "expected #{link} to exist"
    assert_equal expected, File.realpath(link)
  end
end
