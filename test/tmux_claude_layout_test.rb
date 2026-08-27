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
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "" }
        }
      }
    )

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    assert_predicate status, :success?, err
    assert_includes commands, ["join-pane", "-h", "-s", "%11", "-t", "@10", "-l", "90"]
  end

  def test_executable_runs_with_bash_available_and_ruby_unavailable
    FileUtils.ln_s("/bin/bash", File.join(@bin_dir, "bash"))
    write_state(
      "current_session" => "$target",
      "client_width" => 240,
      "sessions" => {
        "$target" => { "nvim_window" => "@10" }
      }
    )

    _out, err, status = run_layout(
      "open", "$target", "240", "%12",
      env: { "PATH" => @bin_dir }
    )

    assert_predicate status, :success?, err
    assert commands.any? { |command| command.first == "split-window" }
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

  def test_open_focuses_an_existing_tagged_claude_pane
    write_state(
      "sessions" => {
        "$1" => {
          "claude" => { "pane_id" => "%77", "window_name" => "work", "window_id" => "@70" }
        }
      },
      "targets" => { "%77" => { "window_id" => "@70" } }
    )

    _out, err, status = run_layout("open", "$1", "240", "%12")

    assert_predicate status, :success?, err
    assert_includes commands, ["select-window", "-t", "@70"]
    assert_includes commands, ["select-pane", "-t", "%77"]
    refute commands.any? { |command| %w[split-window new-window].include?(command.first) }
  end

  def test_open_adopts_an_untagged_claude_window
    write_state(
      "sessions" => {
        "$1" => {
          "claude" => {
            "pane_id" => "%72", "window_name" => "", "window_id" => "@71", "tagged" => false
          }
        }
      },
      "targets" => {
        "@71" => { "pane_id" => "%72" },
        "%72" => { "window_id" => "@71" }
      }
    )

    _out, err, status = run_layout("open", "$1", "240", "%12")

    assert_predicate status, :success?, err
    assert_includes commands, ["set-option", "-p", "-t", "%72", "@main_claude", "1"]
    assert_includes commands, ["select-window", "-t", "@71"]
    assert_includes commands, ["select-pane", "-t", "%72"]
  end

  def test_open_creates_a_tagged_standalone_window_when_narrow
    write_state(
      "sessions" => { "$1" => { "nvim_window" => "@10" } },
      "command_pane_ids" => { "new-window" => "%31" }
    )

    _out, err, status = run_layout("open", "$1", "120", "%12")

    assert_predicate status, :success?, err
    assert commands.any? { |command| command.first == "new-window" }
    refute commands.any? { |command| command.first == "split-window" }
    assert_includes commands, ["set-option", "-p", "-t", "%31", "@main_claude", "1"]
  end

  def test_resize_coalesces_rapid_events
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )

    first = spawn_layout("resize", "$1", "240", "%12")
    first_token = wait_for_token(debounce_path)
    second = spawn_layout("resize", "$1", "180", "%12")
    wait_for_token_change(debounce_path, first_token)
    statuses = [first, second].map do |pid|
      Process.wait(pid)
      $?
    end

    assert statuses.all?(&:success?), "superseded resize returned failure: #{statuses.map(&:exitstatus)}"
    layout_commands = commands.select do |command|
      %w[break-pane join-pane resize-pane].include?(command.first)
    end
    assert_equal [["break-pane", "-s", "%11", "-n", ""]], layout_commands
  end

  def test_resize_without_a_claude_pane_is_a_successful_noop
    write_state("sessions" => { "$1" => { "nvim_window" => "@10" } })

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    assert_predicate status, :success?, err
    refute commands.any? { |command|
      %w[break-pane join-pane resize-pane].include?(command.first)
    }
  end

  def test_resize_preserves_focus_when_joining_a_standalone_claude_pane
    write_state(
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "", "window_id" => "@11" }
        }
      },
      "targets" => {
        "@10" => { "window_width" => 150 },
        "%99" => { "window_id" => "@90" }
      }
    )

    _out, err, status = run_layout("resize", "$1", "240", "%99")

    assert_predicate status, :success?, err
    assert_includes commands, ["join-pane", "-h", "-s", "%11", "-t", "@10", "-l", "60"]
    assert_includes commands, ["select-window", "-t", "@90"]
    assert_includes commands, ["select-pane", "-t", "%99"]
  end

  def test_resize_preserves_focus_when_breaking_a_joined_claude_pane
    write_state(
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦", "window_id" => "@10" }
        }
      },
      "targets" => { "%99" => { "window_id" => "@90" } }
    )

    _out, err, status = run_layout("resize", "$1", "180", "%99")

    assert_predicate status, :success?, err
    assert_includes commands, ["break-pane", "-s", "%11", "-n", ""]
    assert_includes commands, ["select-window", "-t", "@90"]
    assert_includes commands, ["select-pane", "-t", "%99"]
  end

  def test_resize_accepts_a_session_name
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "session_ids" => { "work repo; one" => "$1" },
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )

    _out, err, status = run_layout("resize", "work repo; one", "240", "%12")

    assert_predicate status, :success?, err
    assert_includes commands, ["display-message", "-p", "-t", "work repo; one", '#{session_id}']
    assert_includes commands, ["resize-pane", "-t", "%11", "-x", "90"]
  end

  def test_resize_name_and_id_share_a_debounce_namespace
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "session_ids" => { "work" => "$1" },
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )

    first = spawn_layout("resize", "work", "240", "%12")
    first_token = wait_for_token(debounce_path)
    second = spawn_layout("resize", "$1", "180", "%12")
    wait_for_token_change(debounce_path, first_token)
    [first, second].each { |pid| Process.wait(pid) }

    layout_commands = commands.select do |command|
      %w[break-pane join-pane resize-pane].include?(command.first)
    end
    assert_equal [["break-pane", "-s", "%11", "-n", ""]], layout_commands
  end

  def test_resize_debounce_is_isolated_by_session
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        },
        "$2" => {
          "nvim_window" => "@20",
          "claude" => { "pane_id" => "%21", "window_name" => "󰘦" }
        }
      }
    )

    first = spawn_layout("resize", "$1", "220", "%12")
    second = spawn_layout("resize", "$2", "240", "%22")
    [first, second].each { |pid| Process.wait(pid) }

    resized_panes = commands.filter_map do |command|
      command[2] if command.first == "resize-pane"
    end
    assert_equal ["%11", "%21"], resized_panes.sort
  end

  def test_resize_debounce_is_isolated_by_tmux_server
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )

    first = spawn_layout(
      "resize", "$1", "220", "%12",
      env: { "TMUX" => "#{File.join(@tmpdir, "one.sock")},1,0" }
    )
    second = spawn_layout(
      "resize", "$1", "240", "%12",
      env: { "TMUX" => "#{File.join(@tmpdir, "two.sock")},2,0" }
    )
    [first, second].each { |pid| Process.wait(pid) }

    resize_commands = commands.select { |command| command.first == "resize-pane" }
    assert_equal 2, resize_commands.length
  end

  def test_resize_isolation_does_not_depend_on_hash_commands
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        },
        "$2" => {
          "nvim_window" => "@20",
          "claude" => { "pane_id" => "%21", "window_name" => "󰘦" }
        }
      }
    )
    %w[shasum sha256sum cksum].each { |command| install_failing_command(command) }

    first = spawn_layout("resize", "$1", "220", "%12")
    second = spawn_layout("resize", "$2", "240", "%22")
    [first, second].each { |pid| Process.wait(pid) }

    resized_panes = commands.filter_map do |command|
      command[2] if command.first == "resize-pane"
    end
    assert_equal ["%11", "%21"], resized_panes.sort
  end

  def test_resize_rejects_invalid_debounce_identity
    write_state(
      "session_ids" => { "target" => "not-a-session-id" },
      "sessions" => {}
    )

    {
      "invalid TMUX server identity" => ["$1", "not-a-tmux-value"],
      "invalid tmux session ID" => ["target", "#{File.join(@tmpdir, "tmux.sock")},1,0"]
    }.each do |message, (session, tmux)|
      _out, err, status = run_layout("resize", session, "240", "%12", env: { "TMUX" => tmux })

      refute_predicate status, :success?
      assert_includes err, message
    end
  end

  def test_resize_acquires_the_kernel_lock_after_the_holder_is_killed
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )
    Dir.mkdir(private_state_dir, 0o700)
    lock = debounce_lock_path
    holder = Process.spawn(*kernel_lock_command(lock, "sleep", "10"), out: File::NULL, err: File::NULL)
    wait_for_kernel_lock(lock)

    _out, err, status = run_layout("resize", "$1", "240", "%12")
    refute_predicate status, :success?
    assert_includes err, "failed to acquire debounce lock"

    Process.kill("KILL", holder)
    Process.wait(holder)
    holder = nil
    FileUtils.rm_f(@log_file)
    _out, err, status = run_layout("resize", "$1", "240", "%12")

    assert_predicate status, :success?, err
    assert_path_exists lock
    assert_includes commands, ["resize-pane", "-t", "%11", "-x", "90"]
  ensure
    if holder
      Process.kill("KILL", holder)
      Process.wait(holder)
    end
  end

  def test_resize_fails_when_the_lock_parent_is_inaccessible
    write_state("sessions" => {})
    invalid_tmpdir = File.join(@tmpdir, "not-a-directory")
    File.write(invalid_tmpdir, "")
    err_file = File.join(@tmpdir, "layout.err")

    pid = spawn_layout(
      "resize", "$1", "240", "%12",
      env: { "TMPDIR" => invalid_tmpdir }, err: err_file
    )
    status = wait_for_process(pid)

    refute_nil status, "resize retried a permanent filesystem error"
    refute_predicate status, :success?
    refute_includes File.read(err_file), "failed to acquire debounce lock"
  end

  def test_resize_fails_when_the_debounce_token_cannot_be_written
    write_state("sessions" => {})
    Dir.mkdir(private_state_dir, 0o700)
    FileUtils.mkdir(debounce_path)

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    refute_predicate status, :success?
    assert_includes err, "failed to write debounce token"
    refute_includes err, "failed to acquire debounce lock"
  end

  def test_resize_fails_when_the_debounce_token_cannot_be_removed
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )
    install_token_removal_failure

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    refute_predicate status, :success?
    assert_includes err, "failed to remove debounce token"
    refute commands.any? { |command| command.first == "resize-pane" }
  end

  def test_resize_creates_a_private_debounce_state_directory
    write_state(
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "󰘦" }
        }
      }
    )

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    assert_predicate status, :success?, err
    assert File.directory?(private_state_dir)
    assert_equal 0o700, File.stat(private_state_dir).mode & 0o777
    assert_path_exists debounce_lock_path
  end

  def test_resize_rejects_a_symlinked_debounce_state_directory
    write_state("sessions" => {})
    attacker_dir = File.join(@tmpdir, "attacker")
    FileUtils.mkdir(attacker_dir)
    File.symlink(attacker_dir, private_state_dir)

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    refute_predicate status, :success?
    assert_includes err, "unsafe debounce state directory"
    assert_empty Dir.children(attacker_dir)
  end

  def test_resize_rejects_an_overly_permissive_debounce_state_directory
    write_state("sessions" => {})
    Dir.mkdir(private_state_dir, 0o755)

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    refute_predicate status, :success?
    assert_includes err, "unsafe debounce state directory permissions"
  end

  def test_resize_stops_when_tmux_cannot_read_the_target_width
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "fail_formats" => ['#{window_width}'],
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "" }
        }
      }
    )

    _out, err, status = run_layout("resize", "$1", "240", "%12")

    refute_predicate status, :success?
    assert_match(/tmux command failed/, err)
    refute commands.any? { |command| command.first == "join-pane" }
  end

  def test_resize_rejects_an_empty_target_width
    write_state(
      "current_session" => "$1",
      "client_width" => 240,
      "empty_formats" => ['#{window_width}'],
      "sessions" => {
        "$1" => {
          "nvim_window" => "@10",
          "claude" => { "pane_id" => "%11", "window_name" => "" }
        }
      }
    )

    _out, err, status = run_layout("resize", "$1", "240", "%12")

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
    tmux_server("set-hook", "-g", "client-session-changed[40]", 'run-shell "demux event session_changed"')
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
    assert_includes session_hook, "demux event session_changed"
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

  def run_layout(*args, env: {})
    Open3.capture3(layout_env.merge(env), SCRIPT, *args)
  end

  def spawn_layout(*args, env: {}, err: File::NULL)
    Process.spawn(layout_env.merge(env), SCRIPT, *args, out: File::NULL, err: err)
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

  def wait_for_process(pid, timeout: 1)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until Process.waitpid(pid, Process::WNOHANG)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        Process.kill("TERM", pid)
        Process.wait(pid)
        return nil
      end
      sleep 0.01
    end
    $?
  end

  def wait_for_token(path)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
    loop do
      return File.read(path) if File.file?(path) && !File.zero?(path)
      raise "debounce token was not published: #{path}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.005
    end
  end

  def wait_for_token_change(path, previous_token)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
    loop do
      if File.file?(path) && !File.zero?(path)
        token = File.read(path)
        return token if token != previous_token
      end
      raise "debounce token was not replaced: #{path}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.005
    end
  end

  def debounce_path(server_pid: 1, session: "$1")
    File.join(private_state_dir, "tmux_claude_resize.#{server_pid}.#{session.delete_prefix("$")}.debounce")
  end

  def private_state_dir
    File.join(@tmpdir, "tmux_claude_layout.#{Process.euid}")
  end

  def debounce_lock_path
    "#{debounce_path}.os.lock"
  end

  def kernel_lock_command(lock, *command)
    if RbConfig::CONFIG.fetch("host_os").include?("darwin")
      ["/usr/bin/lockf", "-k", "-t", "0", lock, *command]
    else
      ["flock", "-w", "0", lock, *command]
    end
  end

  def wait_for_kernel_lock(lock)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
    loop do
      _out, _err, status = Open3.capture3(*kernel_lock_command(lock, "true"))
      return unless status.success?
      raise "kernel lock holder did not acquire #{lock}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.005
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
    File.write(path, "#!#{RbConfig.ruby}\n" + <<~'RUBY')
      require "json"

      File.open(ENV.fetch("TMUX_FAKE_LOG"), "a") do |file|
        file.puts(JSON.generate(ARGV))
      end

      state = JSON.parse(File.read(ENV.fetch("TMUX_FAKE_STATE")))
      command = ARGV[0]
      target_index = ARGV.index("-t")
      target = target_index && ARGV[target_index + 1]
      session = state.fetch("sessions", {}).fetch(target, {})
      target_state = state.fetch("targets", {}).fetch(target, {})

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
                when '#{window_width}' then target_state.fetch("window_width", 240)
                when '#{pane_id}' then target_state.fetch("pane_id", "%active")
                when '#{window_id}' then target_state.fetch("window_id", "@10")
                when '#{pane_current_path}' then target_state.fetch("pane_current_path", Dir.pwd)
                when '#{session_id}' then state.fetch("session_ids", {})[target]
                end
        puts value if value
      when "list-panes"
        claude = session["claude"]
        if claude
          flag = claude.fetch("tagged", true) ? "1" : ""
          puts "#{flag}:#{claude["pane_id"]}:#{claude["window_name"]}"
        end
      when "list-windows"
        puts "󰘦:#{session["nvim_window"]}" if session["nvim_window"]
        claude = session["claude"]
        if claude && claude["window_name"] == ""
          puts "#{claude["window_name"]}:#{claude.fetch("window_id", "@11")}"
        end
      when "split-window", "new-window"
        pane_id = state.fetch("command_pane_ids", {})[command]
        puts pane_id if pane_id
      end
    RUBY
    FileUtils.chmod(0o755, path)
  end

  def install_failing_command(command)
    path = File.join(@bin_dir, command)
    File.write(path, "#!/bin/sh\nexit 1\n")
    FileUtils.chmod(0o755, path)
  end

  def install_token_removal_failure
    path = File.join(@bin_dir, "rm")
    File.write(path, <<~'SH')
      #!/bin/sh
      last=
      for argument do last=$argument; done
      case "$last" in
        *.debounce) exit 1 ;;
        *) exec /bin/rm "$@" ;;
      esac
    SH
    FileUtils.chmod(0o755, path)
  end
end
