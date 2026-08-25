#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class KeyboardLayoutTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/keyboard_layout", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @command_log = File.join(@tmpdir, "commands.log")
    @path_log = File.join(@tmpdir, "path.log")
    FileUtils.mkdir_p(@bin_dir)
    File.symlink("/bin/bash", File.join(@bin_dir, "bash"))
    install_fake_defaults
    install_fake_uname
    %w[awk cut grep tr].each { |command| install_recording_wrapper(command) }
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_macos_prints_normalized_keyboard_layout_prefix
    stdout, stderr, status = run_script("darwin23")

    assert_predicate status, :success?, stderr
    assert_equal "US\n", stdout
  end

  def test_linux_prints_fallback_without_running_platform_commands
    stdout, stderr, status = run_script("linux-gnu")

    assert_predicate status, :success?, stderr
    assert_equal "󰖭 \n", stdout
    assert_empty commands
  end

  def test_macos_uses_only_defaults_and_one_parser_process
    _stdout, stderr, status = run_script("darwin23")

    assert_predicate status, :success?, stderr
    assert_equal({ "awk" => 1, "defaults" => 1 }, commands.tally)
  end

  def test_macos_commands_run_with_only_the_controlled_path
    _stdout, stderr, status = run_script("darwin23")

    assert_predicate status, :success?, stderr
    assert_equal @bin_dir, File.read(@path_log).chomp
  end

  private

  def run_script(ostype)
    Open3.capture3(
      {
        "COMMAND_LOG" => @command_log,
        "PATH_LOG" => @path_log,
        "OSTYPE" => ostype,
        "PATH" => @bin_dir
      },
      SCRIPT
    )
  end

  def commands
    return [] unless File.exist?(@command_log)

    File.readlines(@command_log, chomp: true)
  end

  def install_fake_defaults
    write_command("defaults", <<~'SH')
      #!/bin/sh
      printf '%s\n' defaults >> "$COMMAND_LOG"
      printf '%s\n' "$PATH" > "$PATH_LOG"
      printf '%s\n' '({' '    "InputSourceKind" = "Keyboard Layout";' '    "KeyboardLayout Name" = "u.s.";' '})'
    SH
  end

  def install_fake_uname
    write_command("uname", <<~'SH')
      #!/bin/sh
      printf '%s\n' uname >> "$COMMAND_LOG"
      printf '%s\n' Darwin
    SH
  end

  def install_recording_wrapper(command)
    write_command(command, <<~SH)
      #!/bin/sh
      printf '%s\\n' #{command} >> "$COMMAND_LOG"
      exec /usr/bin/#{command} "$@"
    SH
  end

  def write_command(name, contents)
    path = File.join(@bin_dir, name)
    File.write(path, contents)
    FileUtils.chmod(0o755, path)
  end
end
