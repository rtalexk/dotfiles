import { atom, memberOf, read, update } from 'claude-code'
import type { Register } from 'claude-code'

const sentAt = atom({ plugin: 'message-timestamps', key: 'sentAt' } as const, null)
const now = atom({ plugin: 'message-timestamps', key: 'now' } as const, 0)

const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

// Longer tokens come first so MMM is not read as MM followed by M.
const TOKEN = /\[([^\]]*)\]|relative|YYYY|YY|MMM|MM|M|DD|D|ddd|HH|H|hh|h|mm|m|ss|s|A|a|Z/g

const pad = (n: number) => String(n).padStart(2, '0')

type Settings = {
  formats: { today: string; week: string; year: string; older: string }
  isLongUnits: boolean
  hasAgo: boolean
}

const plural = (n: number, unit: string) => `${n} ${unit}${n === 1 ? '' : 's'}`

function relative(at: number, current: number, settings: Settings): string {
  const elapsed = Math.max(0, current - at)
  if (elapsed < MINUTE) return 'just now'

  const minutes = Math.floor(elapsed / MINUTE)
  const hours = Math.floor(elapsed / HOUR)
  const days = Math.floor(elapsed / DAY)
  const amount = settings.isLongUnits
    ? elapsed < HOUR ? `${minutes} min` : elapsed < DAY ? plural(hours, 'hour') : plural(days, 'day')
    : elapsed < HOUR ? `${minutes}m` : elapsed < DAY ? `${hours}h` : `${days}d`

  return settings.hasAgo ? `${amount} ago` : amount
}

function daysBefore(t: number, days: number): number {
  const d = new Date(t)
  d.setDate(d.getDate() - days)

  return d.setHours(0, 0, 0, 0)
}

function formatFor(at: number, current: number, settings: Settings): string {
  const { formats } = settings
  if (at >= daysBefore(current, 0)) return formats.today
  if (at >= daysBefore(current, 6)) return formats.week
  if (new Date(at).getFullYear() === new Date(current).getFullYear()) return formats.year

  return formats.older
}

function offset(d: Date): string {
  const minutes = -d.getTimezoneOffset()
  const sign = minutes < 0 ? '-' : '+'

  return `${sign}${pad(Math.floor(Math.abs(minutes) / 60))}:${pad(Math.abs(minutes) % 60)}`
}

function formatTime(at: number, current: number, format: string, settings: Settings): string {
  const d = new Date(at)
  const hour12 = d.getHours() % 12 || 12
  const tokens: Record<string, () => string> = {
    relative: () => relative(at, current, settings),
    YYYY: () => String(d.getFullYear()),
    YY: () => pad(d.getFullYear() % 100),
    MMM: () => MONTHS[d.getMonth()] ?? '',
    MM: () => pad(d.getMonth() + 1),
    M: () => String(d.getMonth() + 1),
    DD: () => pad(d.getDate()),
    D: () => String(d.getDate()),
    ddd: () => WEEKDAYS[d.getDay()] ?? '',
    HH: () => pad(d.getHours()),
    H: () => String(d.getHours()),
    hh: () => pad(hour12),
    h: () => String(hour12),
    mm: () => pad(d.getMinutes()),
    m: () => String(d.getMinutes()),
    ss: () => pad(d.getSeconds()),
    s: () => String(d.getSeconds()),
    A: () => (d.getHours() < 12 ? 'AM' : 'PM'),
    a: () => (d.getHours() < 12 ? 'am' : 'pm'),
    Z: () => offset(d),
  }

  return format.replace(TOKEN, (token, literal?: string) => literal ?? tokens[token]?.() ?? token)
}

const label = (at: number, current: number, settings: Settings) =>
  formatTime(at, current, formatFor(at, current, settings), settings)

export const register: Register = (on, options) => {
  const text = (key: string, fallback: string) => String(options[key] || fallback)
  const settings: Settings = {
    formats: {
      today: text('formatToday', 'HH:mm · relative'),
      week: text('formatWeek', 'ddd, HH:mm · relative'),
      year: text('formatYear', 'MMM D, HH:mm · relative'),
      older: text('formatOlder', 'MMM D YYYY, HH:mm'),
    },
    isLongUnits: options.relativeUnits === 'long',
    hasAgo: options.relativeAgo !== false,
  }
  // Unset falls back to the default; an empty string turns the hover off.
  const hoverFormat = String(options.formatHover ?? 'YYYY-MM-DD HH:mm:ss Z')
  const patterns = [...Object.values(settings.formats), hoverFormat]
  // A message moves to another pattern as days pass, so differing patterns need the clock too.
  const isLive =
    new Set(Object.values(settings.formats)).size > 1 ||
    patterns.some(pattern => pattern.replace(/\[[^\]]*\]/g, '').includes('relative'))
  const refreshMs = Math.max(1, Number(options.refreshSeconds) || 15) * 1000

  on('session.start', async ($, e, next) => {
    if (isLive) {
      const tick = async () => {
        const at = await $.clock.now()
        await update($, now, () => at)
      }
      await tick()
      $.clock.every(refreshMs, () => void tick())
    }

    return next(e)
  })

  on('session.append', async ($, e, next) => {
    const isMessage =
      e.door === 'prompt' || (e.door === 'response' && e.message.role === 'assistant')
    if (isMessage) {
      const at = await $.clock.now()
      await update($, memberOf(sentAt, { requestId: e.uuid }), () => at)
    }

    return next(e)
  })

  on('ui.render', async ($, e, next) => {
    const isStamped =
      e.component === 'UserMessage' ||
      (e.component === 'AssistantMessage' && e.props.isFirstOfReply)
    if (!isStamped) return next(e)

    const at = await read($, memberOf(sentAt, e))
    if (at === null) return next(e)
    const current = isLive ? Math.max(at, await read($, now)) : at
    const stamp = label(at, current, settings)
    const hover = hoverFormat && formatTime(at, current, hoverFormat, settings)

    const { Box, Text } = $.ui.resolve(e)
    const scope = `stamp-${e.requestId}`
    const width = Math.max(stamp.length, hover ? hover.length : 0)

    // The engine's row opens with a blank line, so the stamp floats over it. Drawn after the row, it
    // also sits above it for the pointer, which a row laid over the stamp would take instead.
    // A hover can reveal a box but not hide one, so the hover text is revealed over the stamp. Both
    // span the same cells, so hiding the hover text again leaves no cell the stamp does not redraw.
    return (
      <Box flexDirection="column">
        {await next(e)}
        <Box key="stamp" position="absolute" top={0} left={2} width={width} hover={hover ? { scope } : undefined}>
          <Text dimColor>{stamp.padEnd(width)}</Text>
        </Box>
        {hover && (
          <Box key="hover" position="absolute" top={0} left={2} width={width} display="none" hover={{ scope, display: 'flex' }}>
            <Text dimColor>{hover.padEnd(width)}</Text>
          </Box>
        )}
      </Box>
    )
  })
}
