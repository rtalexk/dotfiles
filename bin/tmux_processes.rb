#!/usr/bin/env ruby
# frozen_string_literal: true

# pane-procs.rb — show all processes running in every pane of a tmux session.
#
# Usage:
#   ruby pane-procs.rb [session-name]
#   ruby pane-procs.rb          # all sessions

require "open3"

MACOS = RUBY_PLATFORM.include?("darwin")

# ── 1. Get all panes ──────────────────────────────────────────────────────────

def get_panes(session = nil)
  fmt = '#{session_name}|#{window_index}|#{window_name}|#{pane_index}|#{pane_pid}|#{pane_current_command}'
  cmd = ["tmux", "list-panes", "-F", fmt]
  cmd += session ? ["-s", "-t", session] : ["-a"]

  out, err, status = Open3.capture3(*cmd)
  unless status.success?
    warn "tmux error: #{err.strip}"
    exit 1
  end

  out.strip.lines.filter_map do |line|
    parts = line.chomp.split("|")
    next unless parts.length == 6

    {
      session:  parts[0],
      win_idx:  parts[1].to_i,
      win_name: parts[2],
      pane_idx: parts[3].to_i,
      pane_pid: parts[4].to_i,
      cur_cmd:  parts[5],
    }
  end
end

# ── 2. Snapshot all processes with rich fields (one ps call) ──────────────────
#
# Fields: pid, ppid, %cpu, %mem, etime (elapsed), rss (KB), args (full cmdline)
# macOS ps doesn't support --no-headers or some GNU fields, so we branch.

def get_all_procs
  if MACOS
    out, = Open3.capture3("ps", "-ax", "-o", "pid=,ppid=,pcpu=,pmem=,etime=,rss=,command=")
  else
    out, = Open3.capture3("ps", "-e", "-o", "pid,ppid,pcpu,pmem,etime,rss,cmd", "--no-headers")
  end

  procs    = {}
  children = Hash.new { |h, k| h[k] = [] }

  out.strip.lines.each do |line|
    # columns: pid ppid cpu% mem% elapsed rss cmd...
    parts = line.strip.split(nil, 7)
    next if parts.length < 6

    pid     = parts[0].to_i
    ppid    = parts[1].to_i
    cpu     = parts[2].to_f
    mem     = parts[3].to_f
    elapsed = parts[4]&.strip || ""
    rss     = parts[5].to_i   # kilobytes
    cmd     = parts[6]&.strip || ""

    procs[pid] = { pid: pid, ppid: ppid, cpu: cpu, mem: mem,
                   elapsed: elapsed, rss: rss, cmd: cmd }
    children[ppid] << pid
  end

  [procs, children]
end

# ── 3. Working directory per PID ──────────────────────────────────────────────

def cwd_for(pid)
  if MACOS
    out, = Open3.capture3("lsof", "-a", "-p", pid.to_s, "-d", "cwd", "-Fn")
    out.lines.find { |l| l.start_with?("n") }&.then { |l| l[1..].strip }
  else
    File.readlink("/proc/#{pid}/cwd")
  end
rescue
  nil
end

# ── 4. Port → PID mapping ─────────────────────────────────────────────────────

def get_ports_by_pid
  port_map = Hash.new { |h, k| h[k] = [] }

  out, _, status = Open3.capture3("lsof", "-iTCP", "-sTCP:LISTEN", "-nP", "-Fp", "-Fn")

  if status.success?
    cur_pid = nil
    out.each_line do |line|
      if line.start_with?("p")
        cur_pid = line[1..].to_i
      elsif line.start_with?("n") && cur_pid
        port_map[cur_pid] << $1.to_i if line =~ /:(\d+)$/
      end
    end
  else
    # ss fallback (Linux without lsof)
    out2, = Open3.capture3("ss", "-tlnp")
    out2.each_line do |line|
      next unless line =~ /:(\d+)\s/ && line =~ /pid=(\d+)/
      port_map[$2.to_i] << $1.to_i
    end
  end

  port_map
end

# ── 5. Walk the process tree ──────────────────────────────────────────────────

def tree_under(pid, procs, children, depth: 0, max_depth: 4, &block)
  return unless procs.key?(pid) && depth <= max_depth

  block.call(depth, procs[pid])
  children[pid].each do |child_pid|
    tree_under(child_pid, procs, children, depth: depth + 1, max_depth: max_depth, &block)
  end
end

# ── 6. Formatting helpers ─────────────────────────────────────────────────────

IGNORE_CMDS = %w[ps grep sh bash zsh fish -zsh -bash].freeze

def noise?(cmd)
  IGNORE_CMDS.include?(File.basename(cmd.split.first || ""))
end

def shorten_path(path, max = 40)
  return path if path.length <= max
  "…#{path[-(max - 1)..]}"
end

def format_cmd(cmd)
  parts = cmd.split
  return cmd if parts.empty?

  exe  = File.basename(parts[0])
  args = parts[1..]

  if %w[node python python3 ruby bundle].include?(exe) && args.any?
    script = args.find { |a| !a.start_with?("-") }
    flags  = args.select { |a| a.start_with?("-") }.first(2).join(" ")
    label  = script ? "#{exe} #{File.basename(script)}" : exe
    label += " #{flags}" unless flags.empty?
    return label
  end

  meaningful = args.reject { |a| a =~ /^--?(no-)?color|^--silent|^--quiet/ }.first(3)
  label = exe
  label += " #{meaningful.map { |a| shorten_path(a, 30) }.join(" ")}" if meaningful.any?
  label
end

def format_mem(rss_kb)
  mb = rss_kb / 1024.0
  mb >= 1 ? "#{mb.round(1)} MB" : "#{rss_kb} KB"
end

def format_elapsed(elapsed)
  return elapsed if elapsed.empty?
  parts = elapsed.split(/[-:]/)
  case parts.length
  when 2 then "#{parts[0]}m#{parts[1]}s"
  when 3 then "#{parts[0]}h#{parts[1]}m"
  when 4 then "#{parts[0]}d#{parts[1]}h"
  else elapsed
  end
end

# ── 7. Render ─────────────────────────────────────────────────────────────────

BOLD   = "\e[1m"
DIM    = "\e[2m"
CYAN   = "\e[36m"
GREEN  = "\e[32m"
YELLOW = "\e[33m"
RED    = "\e[31m"
RESET  = "\e[0m"

def cpu_color(pct)
  if    pct > 50 then RED
  elsif pct > 10 then YELLOW
  else GREEN
  end
end

def render(panes, procs, children, ports)
  sessions = panes
    .group_by { |p| p[:session] }
    .transform_values { |ps| ps.group_by { |p| p[:win_idx] } }

  sessions.sort.each do |sname, windows|
    puts "\n#{BOLD}#{CYAN}session: #{sname}#{RESET}"

    windows.sort.each do |win_idx, wpanes|
      win_name = wpanes.first[:win_name]
      puts "  #{BOLD}window #{win_idx}: #{win_name}#{RESET}"

      wpanes.sort_by { |p| p[:pane_idx] }.each do |pane|
        ppid = pane[:pane_pid]
        puts "    #{DIM}pane #{pane[:pane_idx]}  (shell pid #{ppid})#{RESET}"

        shown = 0
        tree_under(ppid, procs, children) do |depth, proc|
          next if depth == 0
          next if noise?(proc[:cmd])

          pid      = proc[:pid]
          label    = format_cmd(proc[:cmd])
          cpu_str  = "cpu #{cpu_color(proc[:cpu])}#{proc[:cpu].round(1)}%#{RESET}"
          mem_str  = "mem #{format_mem(proc[:rss])}"
          time_str = "up #{format_elapsed(proc[:elapsed])}"
          pids     = ports[pid]
          port_str = pids.any? ? "  #{GREEN}listening :#{pids.join(", :")}#{RESET}" : ""
          dir      = cwd_for(pid)
          dir_str  = dir ? "  #{DIM}#{shorten_path(dir)}#{RESET}" : ""

          indent       = "      " + "  " * (depth - 1) + "└─ "
          stats_indent = "      " + "  " * (depth - 1) + "   "
          puts "#{indent}#{BOLD}#{label}#{RESET}  #{DIM}[#{pid}]#{RESET}#{port_str}"
          puts "#{stats_indent}#{DIM}#{cpu_str}  #{mem_str}  #{time_str}#{dir_str}#{RESET}"

          shown += 1
        end

        puts "      #{DIM}(idle)#{RESET}" if shown == 0
      end
    end
  end
end

# ── main ──────────────────────────────────────────────────────────────────────

session         = ARGV[0]
panes           = get_panes(session)
procs, children = get_all_procs
ports           = get_ports_by_pid

render(panes, procs, children, ports)
