# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class TmuxClaudeLayoutTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/tmux_claude_layout", __dir__)
  TMUX_CONFIG = File.expand_path("../tmux/.tmux.conf", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @bin_dir = File.join(@tmpdir, "bin")
    @state_file = File.join(@tmpdir, "state.json")
    @log_file = File.join(@tmpdir, "tmux.log")
    FileUtils.mkdir_p(@bin_dir)
    install_fake_tmux
  end

  def teardown
    tmux_server("kill-server") if @tmux_socket
    @control_streams&.each { |stream| stream.close unless stream.closed? }
    FileUtils.remove_entry(@tmpdir)
  end

  def test_resize_uses_captured_session_and_width
    write_state(
      "current_session" => "$wrong",
      "client_width" => 120,
      "sessions" => {
        "$target" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "" }
        }
      }
    )

    _out, err, status = run_layout("resize", "$target", "240", "%12")

    assert_predicate status, :success?, err
    assert_includes commands, ["join-pane", "-h", "-s", "%11", "-t", "@10", "-l", "90"]
  end

  def test_open_uses_captured_session_width_and_source_pane
    write_state(
      "current_session" => "$wrong",
      "client_width" => 120,
      "sessions" => {
        "$target" => { "nvim_window" => "@10" }
      }
    )

    _out, err, status = run_layout("open", "$target", "240", "%12")

    assert_predicate status, :success?, err
    split = commands.find { |command| command.first == "split-window" }
    refute_nil split
    assert_equal "@10", split[split.index("-t") + 1]
    assert_equal "90", split[split.index("-l") + 1]
    assert_includes commands, ["display-message", "-p", "-t", "%12", '#{pane_current_path}']
  end

  def test_resize_coalesces_rapid_events
    write_state(
      "current_session" => "$target",
      "client_width" => 240,
      "sessions" => {
        "$target" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )

    first = spawn_layout("resize", "$target", "240", "%12")
    sleep 0.03
    second = spawn_layout("resize", "$target", "180", "%12")
    [first, second].each { |pid| Process.wait(pid) }

    layout_commands = commands.select do |command|
      %w[break-pane join-pane resize-pane].include?(command.first)
    end
    assert_equal [["break-pane", "-s", "%11", "-n", ""]], layout_commands
  end

  def test_resize_debounce_is_isolated_by_session
    write_state(
      "current_session" => "$one",
      "client_width" => 240,
      "sessions" => {
        "$one" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        },
        "$two" => {
          "nvim_window" => "@20",
          "claude" => { "pane_id" => "%21", "window_name" => "󰘦" }
        }
      }
    )

    first = spawn_layout("resize", "$one", "220", "%12")
    second = spawn_layout("resize", "$two", "240", "%22")
    [first, second].each { |pid| Process.wait(pid) }

    resized_panes = commands.filter_map do |command|
      command[2] if command.first == "resize-pane"
    end
    assert_equal ["%11", "%21"], resized_panes.sort
  end

  def test_resize_debounce_is_isolated_by_tmux_server
    write_state(
      "current_session" => "$target",
      "client_width" => 240,
      "sessions" => {
        "$target" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )

    first = spawn_layout(
      "resize", "$target", "220", "%12",
      env: { "TMUX" => "#{File.join(@tmpdir, "one.sock")},1,0" }
    )
    second = spawn_layout(
      "resize", "$target", "240", "%12",
      env: { "TMUX" => "#{File.join(@tmpdir, "two.sock")},1,0" }
    )
    [first, second].each { |pid| Process.wait(pid) }

    resize_commands = commands.select { |command| command.first == "resize-pane" }
    assert_equal 2, resize_commands.length
  end

  def test_resize_stops_when_tmux_cannot_read_the_target_width
    write_state(
      "current_session" => "$target",
      "client_width" => 240,
      "fail_formats" => ['#{window_width}'],
      "sessions" => {
        "$target" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "" }
        }
      }
    )

    _out, err, status = run_layout("resize", "$target", "240", "%12")

    refute_predicate status, :success?
    assert_match(/tmux command failed/, err)
    refute commands.any? { |command| command.first == "join-pane" }
  end

  def test_resize_rejects_an_empty_target_width
    write_state(
      "current_session" => "$target",
      "client_width" => 240,
      "empty_formats" => ['#{window_width}'],
      "sessions" => {
        "$target" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "" }
        }
      }
    )

    _out, err, status = run_layout("resize", "$target", "240", "%12")

    refute_predicate status, :success?
    assert_match(/invalid window width/, err)
    refute commands.any? { |command| command.first == "join-pane" }
  end

  def test_config_captures_context_for_resize_and_session_change_hooks
    @tmux_socket = "tmux-claude-layout-test-#{Process.pid}"
    _out, err, status = tmux_server("-f", "/dev/null", "new-session", "-d", "-s", "test")
    assert_predicate status, :success?, err
    _out, err, status = tmux_server("new-session", "-d", "-s", "second")
    assert_predicate status, :success?, err
    install_layout_recorder
    config = isolated_layout_config
    tmux_server("set-environment", "-g", "PATH", "#{@bin_dir}:#{ENV.fetch("PATH")}")
    tmux_server("set-environment", "-g", "TMUX_LAYOUT_HOOK_LOG", @hook_log)
    _out, err, status = tmux_server("source-file", config)
    assert_predicate status, :success?, err

    resize_hook, err, status = tmux_server("show-hooks", "-g", "client-resized")
    assert_predicate status, :success?, err
    session_hook, err, status = tmux_server("show-hooks", "-g", "client-session-changed")
    assert_predicate status, :success?, err
    open_binding, err, status = tmux_server("list-keys", "-T", "prefix")
    assert_predicate status, :success?, err

    expected = /tmux_claude_layout resize .*#\{q:session_id\}.*#\{client_width\}.*#\{q:pane_id\}/
    assert_match expected, resize_hook
    assert_match expected, session_hook
    assert_match(/tmux_claude_layout open .*#\{q:session_id\}.*#\{client_width\}.*#\{q:pane_id\}/, open_binding)

    attach_control_client("test")
    client = wait_for_client
    first_session = tmux_value("test", '#{session_id}')
    first_pane = tmux_value("test", '#{pane_id}')
    first_width = client_width_for(client)
    calls = wait_for_hook_calls(1)
    assert_includes calls, ["resize", first_session, first_width, first_pane]

    _out, err, status = tmux_server("refresh-client", "-t", client, "-C", "240,40")
    assert_predicate status, :success?, err
    _out, err, status = tmux_server("switch-client", "-c", client, "-t", "second")
    assert_predicate status, :success?, err
    second_session = tmux_value("second", '#{session_id}')
    second_pane = tmux_value("second", '#{pane_id}')
    calls = wait_for_hook_calls(2)

    assert_includes calls, ["resize", second_session, "240", second_pane]
  end

  private

  def run_layout(*args)
    Open3.capture3(layout_env, RbConfig.ruby, SCRIPT, *args)
  end

  def spawn_layout(*args, env: {})
    Process.spawn(layout_env.merge(env), RbConfig.ruby, SCRIPT, *args, out: File::NULL, err: File::NULL)
  end

  def layout_env
    {
      "PATH" => "#{@bin_dir}:#{ENV.fetch("PATH")}",
      "TMUX" => "#{File.join(@tmpdir, "tmux.sock")},1,0",
      "TMUX_FAKE_LOG" => @log_file,
      "TMUX_FAKE_STATE" => @state_file,
      "TMPDIR" => @tmpdir
    }
  end

  def tmux_server(*args)
    Open3.capture3("tmux", "-L", @tmux_socket, *args)
  end

  def tmux_value(target, format)
    out, err, status = tmux_server("display-message", "-p", "-t", target, format)
    assert_predicate status, :success?, err
    out.strip
  end

  def isolated_layout_config
    path = File.join(@tmpdir, "tmux-layout.conf")
    lines = File.readlines(TMUX_CONFIG).select do |line|
      line.include?("tmux_claude_layout") || line.include?("client-session-changed")
    end
    File.write(path, lines.join)
    path
  end

  def install_layout_recorder
    @hook_log = File.join(@tmpdir, "hook.log")
    path = File.join(@bin_dir, "tmux_claude_layout")
    File.write(path, <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"
      File.open(ENV.fetch("TMUX_LAYOUT_HOOK_LOG"), "a") do |file|
        file.puts(JSON.generate(ARGV))
      end
    RUBY
    FileUtils.chmod(0o755, path)
  end

  def attach_control_client(session)
    stdin, stdout, stderr, wait_thread = Open3.popen3(
      "tmux", "-L", @tmux_socket, "-C", "attach-session", "-t", session
    )
    @control_streams = [stdin, stdout, stderr]
    @control_wait_thread = wait_thread
  end

  def wait_for_client
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    loop do
      out, = tmux_server("list-clients", "-F", '#{client_name}')
      return out.lines.first.strip unless out.strip.empty?
      raise "control client did not attach" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def client_width_for(client)
    out, err, status = tmux_server("list-clients", "-F", '#{client_name}:#{client_width}')
    assert_predicate status, :success?, err
    line = out.lines.find { |candidate| candidate.start_with?("#{client}:") }
    refute_nil line
    line.split(":", 2).last.strip
  end

  def wait_for_hook_calls(count)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    loop do
      calls = if File.exist?(@hook_log)
        File.readlines(@hook_log, chomp: true).map { |line| JSON.parse(line) }
      else
        []
      end
      return calls if calls.length >= count
      raise "expected #{count} hook calls, got #{calls.length}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
  end

  def write_state(state)
    File.write(@state_file, JSON.generate(state))
  end

  def commands
    return [] unless File.exist?(@log_file)

    File.readlines(@log_file, chomp: true).map { |line| JSON.parse(line) }
  end

  def install_fake_tmux
    path = File.join(@bin_dir, "tmux")
    File.write(path, <<~'RUBY')
      #!/usr/bin/env ruby
      require "json"

      File.open(ENV.fetch("TMUX_FAKE_LOG"), "a") do |file|
        file.puts(JSON.generate(ARGV))
      end

      state = JSON.parse(File.read(ENV.fetch("TMUX_FAKE_STATE")))
      command = ARGV[0]
      target_index = ARGV.index("-t")
      target = target_index && ARGV[target_index + 1]
      session = state.fetch("sessions", {}).fetch(target, {})

      if command == "display-message" && state.fetch("fail_formats", []).include?(ARGV.last)
        warn "forced tmux failure"
        exit 1
      end
      exit 0 if command == "display-message" && state.fetch("empty_formats", []).include?(ARGV.last)

      case command
      when "display-message"
        value = case ARGV.last
                when "#S" then state["current_session"]
                when '#{client_width}' then state["client_width"]
                when '#{window_width}' then 240
                when '#{pane_id}' then "%active"
                when '#{window_id}' then "@10"
                when '#{pane_current_path}' then Dir.pwd
                end
        puts value if value
      when "list-panes"
        claude = session["claude"]
        puts "1:#{claude["pane_id"]}:#{claude["window_name"]}" if claude
      when "list-windows"
        puts "󰘦:#{session["nvim_window"]}" if session["nvim_window"]
        claude = session["claude"]
        puts "#{claude["window_name"]}:@11" if claude && claude["window_name"] == ""
      end
    RUBY
    FileUtils.chmod(0o755, path)
  end
end
