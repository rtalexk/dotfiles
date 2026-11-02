import type { On } from 'claude-code'
import type { Mounted } from 'claude-code/testing'
import { expect, mock, test } from 'claude-code/testing'

const SENT = Date.UTC(2026, 9, 30, 14, 32)
const sentClock = () => {
  const d = new Date(SENT)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

// These tests read the stamp as plain text; a hover pattern draws it through a Client instead.
const FIXED = { formatToday: 'HH:mm', formatWeek: 'HH:mm', formatYear: 'HH:mm', formatOlder: 'HH:mm', formatHover: '' }
const sameForAll = (pattern: string) => ({ formatToday: pattern, formatWeek: pattern, formatYear: pattern, formatOlder: pattern, formatHover: '' })

const prompt = (uuid: string) => ({
  message: { type: 'user', role: 'user', content: [{ type: 'text', text: 'hi' }] },
  door: 'prompt',
  origin: { kind: 'person' },
  uuid,
}) as never

const USER_ROW = (surface: 'terminal' | 'vscode', requestId: string) =>
  ({
    plugin: 'message-timestamps',
    component: 'UserMessage',
    surface,
    requestId,
    props: { text: 'hi', origin: { kind: 'prompt' }, isExpanded: false },
  }) as never

test('a prompt row shows its time and how long ago, on terminal and vscode', { options: sameForAll('HH:mm · relative') }, async ($, on) => {
  const clock = mock.clock(on, { now: SENT })
  mock.session(on)
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })

  await $.session.start({ cwd: '/', surface: 'vscode', isInteractive: true })
  await $.session.append(prompt('u1'))
  await clock.advance(23 * 60 * 60_000)

  const rows = await Promise.all(
    (['terminal', 'vscode'] as const).map(surface => $.ui.mount(USER_ROW(surface, 'u1'))),
  )
  for (const ui of rows) {
    expect((await ui.find({ key: 'stamp' }))?.text).toBe(`${sentClock()} · 23h ago`)
  }

  await clock.advance(60 * 60_000)
  for (const ui of rows) {
    expect((await ui.find({ key: 'stamp' }))?.text).toBe(`${sentClock()} · 1d ago`)
    await ui.unmount()
  }
})

test('a row with no recorded time is left to the engine', async ($, on) => {
  mock.clock(on, { now: SENT })
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })

  const ui = await $.ui.mount(USER_ROW('vscode', 'unknown'))
  expect(await ui.drawn()).toMatchObject({ type: 'Text' })
  await ui.unmount()
})

test('a fixed format draws no relative part', { options: FIXED }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })

  await $.session.append(prompt('u2'))
  const ui = await $.ui.mount(USER_ROW('vscode', 'u2'))
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(sentClock())
  await ui.unmount()
})

const reply = (uuid: string) => ({
  message: { type: 'assistant', role: 'assistant', content: [{ type: 'text', text: 'x' }] },
  door: 'response',
  origin: { kind: 'model', model: 'm' },
  uuid,
}) as never

const REPLY_ROW = (requestId: string, text: string) =>
  ({
    plugin: 'message-timestamps',
    component: 'AssistantMessage',
    surface: 'vscode',
    requestId,
    props: { text, isFirstOfReply: true },
  }) as never

test('a reply shows its time above its first block only', { options: FIXED }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })

  await $.session.append(reply('a1'))
  const first = await $.ui.mount(REPLY_ROW('a1', 'Done.'))
  expect((await first.find({ key: 'stamp' }))?.text).toBe(sentClock())
  expect((await first.find({ type: 'Text', text: /Done/ }))?.text).toBe('Done.')
  await first.unmount()

  const later = await $.ui.mount({ ...(REPLY_ROW('a1', 'More.') as object), props: { text: 'More.', isFirstOfReply: false } } as never)
  expect(await later.drawn()).toMatchObject({ type: 'Text' })
  await later.unmount()
})

test('a row drawn before its message is stored redraws once the time is recorded', { options: FIXED }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })

  const ui = await $.ui.mount(USER_ROW('terminal', 'late'))
  expect(await ui.drawn()).toMatchObject({ type: 'Text' })

  await $.session.append(prompt('late'))
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(sentClock())
  await ui.unmount()
})

test('a custom pattern draws its tokens and keeps bracketed text', { options: { formatToday: '[at] ddd DD MMM YYYY, h:mm:ss A', formatHover: '' } }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })

  const d = new Date(SENT)
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.getDay()]
  const month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.getMonth()]
  const two = (n: number) => String(n).padStart(2, '0')
  const expected = `at ${weekday} ${two(d.getDate())} ${month} ${d.getFullYear()}, ${d.getHours() % 12 || 12}:${two(d.getMinutes())}:${two(d.getSeconds())} ${d.getHours() < 12 ? 'AM' : 'PM'}`

  await $.session.append(prompt('p1'))
  const ui = await $.ui.mount(USER_ROW('vscode', 'p1'))
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(expected)
  await ui.unmount()
})

test('the relative part follows the refresh interval', { options: { formatToday: 'relative', refreshSeconds: 15, formatHover: '' } }, async ($, on) => {
  const clock = mock.clock(on, { now: SENT })
  mock.session(on)
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(10_000)
  await $.session.append(prompt('r1'))
  const ui = await $.ui.mount(USER_ROW('terminal', 'r1'))
  expect((await ui.find({ key: 'stamp' }))?.text).toBe('just now')

  // Sent 10s in: a minute has passed at 70s, and the tick at 75s shows it.
  await clock.advance(65_000)
  expect((await ui.find({ key: 'stamp' }))?.text).toBe('1m ago')
  await ui.unmount()
})

const ROW_TEXT = (on: On) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{'text' in e.props ? String(e.props.text) : 'engine'}</Text>
  })
}

test('each age range uses its own pattern', { options: { refreshSeconds: 3600, formatHover: '' } }, async ($, on) => {
  const clock = mock.clock(on, { now: SENT })
  mock.session(on)
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  ROW_TEXT(on)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.session.append(prompt('age'))
  const ui = await $.ui.mount(USER_ROW('terminal', 'age'))
  const d = new Date(SENT)
  const two = (n: number) => String(n).padStart(2, '0')
  const time = `${two(d.getHours())}:${two(d.getMinutes())}`
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.getDay()]
  const month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.getMonth()]

  expect((await ui.find({ key: 'stamp' }))?.text).toBe(`${time} · just now`)

  await clock.advance(2 * DAY_MS)
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(`${weekday}, ${time} · 2d ago`)

  await clock.advance(8 * DAY_MS)
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(`${month} ${d.getDate()}, ${time} · 10d ago`)

  await clock.advance(400 * DAY_MS)
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(`${month} ${d.getDate()} ${d.getFullYear()}, ${time}`)
  await ui.unmount()
})

const DAY_MS = 24 * 60 * 60_000

for (const [units, hasAgo, minute, hours] of [
  ['short', true, '1m ago', '3h ago'],
  ['short', false, '1m', '3h'],
  ['long', true, '1 min ago', '3 hours ago'],
  ['long', false, '1 min', '3 hours'],
] as const) {
  test(`relative style ${units}, ago ${hasAgo ? 'on' : 'off'}`, { options: { ...sameForAll('relative'), relativeUnits: units, relativeAgo: hasAgo } }, async ($, on) => {
    const clock = mock.clock(on, { now: SENT })
    mock.session(on)
    on('session.start', (_, e) => ({ cwd: e.cwd }))
    ROW_TEXT(on)

    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    await $.session.append(prompt('rel'))
    const ui = await $.ui.mount(USER_ROW('terminal', 'rel'))
    expect((await ui.find({ key: 'stamp' }))?.text).toBe('just now')

    await clock.advance(60_000)
    expect((await ui.find({ key: 'stamp' }))?.text).toBe(minute)

    await clock.advance(3 * 60 * 60_000)
    expect((await ui.find({ key: 'stamp' }))?.text).toBe(hours)
    await ui.unmount()
  })
}

test('hovering the timestamp shows the hover pattern in its place', { options: { ...FIXED, formatHover: 'YYYY-MM-DD HH:mm:ss Z' } }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  ROW_TEXT(on)

  const d = new Date(SENT)
  const two = (n: number) => String(n).padStart(2, '0')
  const minutes = -d.getTimezoneOffset()
  const zone = `${minutes < 0 ? '-' : '+'}${two(Math.floor(Math.abs(minutes) / 60))}:${two(Math.abs(minutes) % 60)}`
  const iso = `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())} ${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())} ${zone}`

  await $.session.append(prompt('h1'))
  const ui = (await $.ui.mount(USER_ROW('terminal', 'h1'))) as Mounted<'terminal', 'UserMessage'>
  const scope = { in: 'stamp-h1' }
  expect(await ui.drawn(scope)).toMatchObject({ type: 'Text', children: [sentClock()] })

  await ui.pointer({ type: 'enter', x: 0, y: 0, ...scope })
  expect(await ui.drawn(scope)).toMatchObject({ type: 'Text', children: [iso] })

  await ui.pointer({ type: 'leave', x: -1, y: 0, ...scope })
  expect(await ui.drawn(scope)).toMatchObject({ type: 'Text', children: [sentClock()] })
  await ui.unmount()
})

test('vscode has no Client, so the stamp stays plain text there', { options: { ...FIXED, formatHover: 'YYYY' } }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  ROW_TEXT(on)

  await $.session.append(prompt('h3'))
  const ui = await $.ui.mount(USER_ROW('vscode', 'h3'))
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(sentClock())
  await ui.unmount()
})

test('an empty hover pattern draws no hover', { options: { ...FIXED, formatHover: '' } }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  ROW_TEXT(on)

  await $.session.append(prompt('h2'))
  const ui = await $.ui.mount(USER_ROW('terminal', 'h2'))
  expect(JSON.stringify(await ui.drawn())).not.toContain('Client')
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(sentClock())
  await ui.unmount()
})

test('z names the time zone', { options: { ...FIXED, formatToday: 'z' } }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  ROW_TEXT(on)

  const zone = new Intl.DateTimeFormat('en-US', { timeZoneName: 'short' }).formatToParts(new Date(SENT)).find(part => part.type === 'timeZoneName')?.value

  await $.session.append(prompt('z1'))
  const ui = await $.ui.mount(USER_ROW('vscode', 'z1'))
  expect((await ui.find({ key: 'stamp' }))?.text).toBe(zone)
  await ui.unmount()
})

test('an icon goes before the timestamp and another before the hover text', { options: { ...FIXED, formatHover: 'HH', icon: '>', iconHover: '*' } }, async ($, on) => {
  mock.clock(on, { now: SENT })
  mock.session(on)
  ROW_TEXT(on)

  await $.session.append(prompt('i1'))
  const ui = (await $.ui.mount(USER_ROW('terminal', 'i1'))) as Mounted<'terminal', 'UserMessage'>
  const scope = { in: 'stamp-i1' }
  expect(await ui.drawn(scope)).toMatchObject({ type: 'Text', children: [`> ${sentClock()}`] })

  await ui.pointer({ type: 'enter', x: 0, y: 0, ...scope })
  expect(await ui.drawn(scope)).toMatchObject({ type: 'Text', children: [`* ${sentClock().slice(0, 2)}`] })
  await ui.unmount()
})
