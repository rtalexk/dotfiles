#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class GitmuxTextTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/gitmux_text", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @repo = File.join(@tmpdir, "repo")
    @cache = File.join(@tmpdir, "cache")
    @log = File.join(@tmpdir, "commands.log")
    FileUtils.mkdir_p([@bin_dir, @repo, @cache])
    install_fakes
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_cached_pr_uses_one_git_process_and_preserves_output
    run_script
    wait_for_cache
    File.write(@log, "")

    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_equal "#[fg=green]main#[none]#[bg=#313244,fg=colour244] PR #[bg=#313244,fg=colour220]#42#[none]\n", stdout
    assert_equal 1, command_log.count { |line| line.start_with?("git ") }
    refute command_log.any? { |line| line.start_with?("is_git_repo ") }
  end

  def test_uncached_pr_is_refreshed_asynchronously
    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_equal "#[fg=green]main#[none]\n", stdout

    wait_for_cache
    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_equal "#[fg=green]main#[none]#[bg=#313244,fg=colour244] PR #[bg=#313244,fg=colour220]#42#[none]\n", stdout
  end

  def test_bare_repository_parent_preserves_static_indicator
    stdout, stderr, status = run_script("FAKE_BARE" => "1")

    assert status.success?, stderr
    assert_equal "#[fg=white,bold]_bare_#[none]\n", stdout
  end

  def test_combined_rev_parse_preserves_newlines_in_the_repository_path
    @repo = File.join(@tmpdir, "repo\nwith-newline")
    FileUtils.mkdir(@repo)

    run_script
    wait_for_cache
    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_equal "#[fg=green]main#[none]#[bg=#313244,fg=colour244] PR #[bg=#313244,fg=colour220]#42#[none]\n", stdout
    cache_entries = Dir.children(File.join(@cache, "gitmux_text"))
    assert cache_entries.any? { |entry| entry.start_with?("repo\nwith-newline-main-") }
  end

  private

  def run_script(extra_env = {})
    env = {
      "PATH" => "#{@bin_dir}:#{ENV.fetch("PATH")}",
      "XDG_CACHE_HOME" => @cache,
      "XDG_CONFIG_HOME" => File.join(@tmpdir, "config"),
      "FAKE_LOG" => @log,
      "FAKE_REPO" => @repo,
      "GITMUX_PR_TTL" => "60"
    }.merge(extra_env)
    Open3.capture3(env, SCRIPT, @repo)
  end

  def wait_for_cache
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    loop do
      cache_file = Dir[File.join(@cache, "gitmux_text", "*")].find do |file|
        File.file?(file) && !file.end_with?(".stamp")
      end
      return if cache_file && File.read(cache_file) == "42"
      raise "PR cache was not refreshed" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def command_log
    File.exist?(@log) ? File.readlines(@log, chomp: true) : []
  end

  def install_fakes
    write_executable("is_git_repo", <<~'SH')
      #!/bin/sh
      printf 'is_git_repo %s\n' "$*" >>"$FAKE_LOG"
      [ -z "$FAKE_BARE" ]
    SH

    write_executable("git", <<~'SH')
      #!/bin/sh
      printf 'git %s\n' "$*" >>"$FAKE_LOG"
      case "$*" in
        *--git-dir=*) [ -n "$FAKE_BARE" ] ;;
        *--show-toplevel*--abbrev-ref*)
          [ -z "$FAKE_BARE" ] || exit 1
          printf '%s\nmain\n' "$FAKE_REPO"
          ;;
        *--show-toplevel*)
          [ -z "$FAKE_BARE" ] || exit 1
          printf '%s\n' "$FAKE_REPO"
          ;;
        *--abbrev-ref*)
          [ -z "$FAKE_BARE" ] || exit 1
          printf 'main\n'
          ;;
        *) exit 1 ;;
      esac
    SH

    write_executable("gitmux", <<~'SH')
      #!/bin/sh
      printf 'gitmux %s\n' "$*" >>"$FAKE_LOG"
      printf '#[fg=green]main#[none]\n'
    SH

    write_executable("gh", <<~'SH')
      #!/bin/sh
      printf 'gh %s\n' "$*" >>"$FAKE_LOG"
      sleep 0.05
      printf 'https://github.com/example/repo/pull/42\n'
    SH

    write_executable("tmux", <<~'SH')
      #!/bin/sh
      printf 'tmux %s\n' "$*" >>"$FAKE_LOG"
      printf '#313244\n'
    SH
  end

  def write_executable(name, contents)
    path = File.join(@bin_dir, name)
    File.write(path, contents)
    FileUtils.chmod(0o755, path)
  end
end
