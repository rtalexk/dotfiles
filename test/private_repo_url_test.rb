#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class PrivateRepoUrlTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/private_repo_url", __dir__)
  URL = "git@github.com:someone/private-config.git"

  def setup
    @tmpdir = Dir.mktmpdir
    @work = File.join(@tmpdir, "work")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def run_script(*args, env: {})
    base = { "DOTFILES_PRIVATE_REPO" => nil, "XDG_CONFIG_HOME" => @tmpdir }
    Open3.capture3(base.merge(env), SCRIPT, *args)
  end

  def test_env_var_wins_over_work_file
    File.write(@work, %(export DOTFILES_PRIVATE_REPO="from-work"\n))

    stdout, _stderr, status = run_script(@work, env: { "DOTFILES_PRIVATE_REPO" => URL })

    assert status.success?
    assert_equal URL, stdout.strip
  end

  def test_reads_assignment_from_work_file
    File.write(@work, %(export DOTFILES_PRIVATE_REPO="#{URL}"\n))

    stdout, _stderr, status = run_script(@work)

    assert status.success?
    assert_equal URL, stdout.strip
  end

  def test_zsh_only_syntax_after_assignment_still_resolves
    File.write(@work, <<~WORK)
      export DOTFILES_PRIVATE_REPO="#{URL}"

      if [ -n "$ZSH_VERSION" ]; then
        _awsp() { compadd off }
        compdef _awsp awsp 2>/dev/null
      fi
    WORK

    stdout, _stderr, status = run_script(@work)

    assert status.success?
    assert_equal URL, stdout.strip
  end

  def test_syntax_error_before_assignment_yields_nothing_and_exits_zero
    File.write(@work, <<~WORK)
      if [ -n "$ZSH_VERSION" ]; then
        _awsp() { compadd off }
      fi

      export DOTFILES_PRIVATE_REPO="#{URL}"
    WORK

    stdout, _stderr, status = run_script(@work)

    assert status.success?, "a broken work file must not fail the caller"
    assert_equal "", stdout.strip
  end

  def test_work_file_without_the_variable_yields_nothing
    File.write(@work, %(export CURRENT_EMPLOYER="somewhere"\n))

    stdout, _stderr, status = run_script(@work)

    assert status.success?
    assert_equal "", stdout.strip
  end

  def test_missing_work_file_yields_nothing
    stdout, _stderr, status = run_script(File.join(@tmpdir, "absent"))

    assert status.success?
    assert_equal "", stdout.strip
  end

  def test_defaults_to_xdg_config_home
    FileUtils.mkdir_p(File.join(@tmpdir, "shell"))
    File.write(File.join(@tmpdir, "shell", "work"), %(export DOTFILES_PRIVATE_REPO="#{URL}"\n))

    stdout, _stderr, status = run_script

    assert status.success?
    assert_equal URL, stdout.strip
  end
end
