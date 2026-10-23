#!/usr/bin/env node
// LSP proxy that fills in client features kak-lsp lacks. Used for tsgo (the
// TypeScript 7 native language server) and vue-language-server.
//
// Diagnostics: some servers (tsgo) only report diagnostics when the client
// pulls them (textDocument/diagnostic, LSP 3.17), while kak-lsp only displays
// diagnostics a server pushes (textDocument/publishDiagnostics). When the
// server advertises a diagnosticProvider, the proxy pulls on kak-lsp's behalf
// and pushes the results back as notifications. Servers that push are left
// alone.
//
// File watching: without a client that watches files, servers never notice
// files changed outside the editor (git checkout, regenerated .d.ts files,
// formatters) and go stale until restarted. kak-lsp's own watcher
// (lsp_file_watch_support) is unusable in a pnpm monorepo: it follows the
// node_modules symlinks, reports changes under aliased paths servers can't
// match, and is too slow to acknowledge registrations. So the proxy handles
// file watcher registrations itself and watches the workspace, skipping
// IGNORED_DIRECTORIES. Servers ignore reported paths they don't care about.
//
// Usage: node lsp-compat-proxy.mjs <server-command> [args...]

import { spawn } from 'node:child_process'
import { readdirSync, statSync, watch } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const PULL_DEBOUNCE_MS = 150
const RETRY_DELAY_MS = 500
const FILE_CHANGE_BATCH_MS = 100
const SERVER_CANCELLED = -32802
const CONTENT_MODIFIED = -32801
const WATCHED_FILES_METHOD = 'workspace/didChangeWatchedFiles'
const IGNORED_DIRECTORIES = new Set(['node_modules', '.git', '.moon'])
const FILE_CREATED = 1
const FILE_CHANGED = 2
const FILE_DELETED = 3

const [command, ...args] = process.argv.slice(2)
const server = spawn(command, args, { stdio: ['pipe', 'pipe', 'inherit'] })

const openDocuments = new Set()
const pullTimers = new Map()
const latestPullByUri = new Map()
const pendingPulls = new Map()
let nextPullId = 0
let initializeRequestId
let serverPullsDiagnostics = false

let workspaceRoot
const watchRegistrations = new Set()
const directoryWatchers = new Map()
const pendingFileChanges = new Map()
let fileChangeTimer

function readMessages(stream, onMessage) {
  let buffer = Buffer.alloc(0)
  stream.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk])
    for (;;) {
      const headerEnd = buffer.indexOf('\r\n\r\n')
      if (headerEnd === -1) return
      const header = buffer.subarray(0, headerEnd).toString('ascii')
      const length = Number(/Content-Length: *(\d+)/i.exec(header)?.[1])
      const bodyStart = headerEnd + 4
      if (buffer.length < bodyStart + length) return
      const body = buffer.subarray(bodyStart, bodyStart + length)
      buffer = buffer.subarray(bodyStart + length)
      onMessage(JSON.parse(body.toString('utf8')))
    }
  })
}

function messageWriter(stream) {
  return (message) => {
    const body = Buffer.from(JSON.stringify(message), 'utf8')
    stream.write(`Content-Length: ${body.length}\r\n\r\n`)
    stream.write(body)
  }
}

const toServer = messageWriter(server.stdin)
const toEditor = messageWriter(process.stdout)

function initialize(params) {
  const rootUri = params.rootUri ?? params.workspaceFolders?.[0]?.uri
  if (rootUri) workspaceRoot = fileURLToPath(rootUri)

  const capabilities = (params.capabilities ??= {})
  const textDocument = (capabilities.textDocument ??= {})
  const workspace = (capabilities.workspace ??= {})
  textDocument.diagnostic ??= { dynamicRegistration: false, relatedDocumentSupport: false }
  workspace.diagnostics ??= { refreshSupport: true }
  workspace.didChangeWatchedFiles = { dynamicRegistration: true, relativePatternSupport: false }
}

// Diagnostics

function schedulePull(uri, delay = PULL_DEBOUNCE_MS) {
  if (!serverPullsDiagnostics) return
  clearTimeout(pullTimers.get(uri))
  pullTimers.set(uri, setTimeout(() => pull(uri), delay))
}

function schedulePullAll() {
  for (const uri of openDocuments) schedulePull(uri)
}

function pull(uri) {
  pullTimers.delete(uri)
  if (!openDocuments.has(uri)) return
  const id = `lsp-compat-proxy-${++nextPullId}`
  latestPullByUri.set(uri, id)
  pendingPulls.set(id, uri)
  toServer({ jsonrpc: '2.0', id, method: 'textDocument/diagnostic', params: { textDocument: { uri } } })
}

function handlePullResponse(uri, message) {
  // Servers may answer requests concurrently, so an older pull can finish last
  if (latestPullByUri.get(uri) !== message.id || !openDocuments.has(uri)) return
  if (message.error) {
    if ([SERVER_CANCELLED, CONTENT_MODIFIED].includes(message.error.code)) schedulePull(uri, RETRY_DELAY_MS)
    return
  }
  if (message.result?.kind !== 'full') return
  toEditor({
    jsonrpc: '2.0',
    method: 'textDocument/publishDiagnostics',
    params: { uri, diagnostics: message.result.items },
  })
}

// File watching

function statOrUndefined(path) {
  try {
    return statSync(path)
  } catch {
    return undefined
  }
}

function watchDirectory(directory, reportExistingFiles) {
  if (directoryWatchers.has(directory)) return
  let watcher, entries
  try {
    watcher = watch(directory, (eventType, filename) => onFileEvent(directory, eventType, filename))
    entries = readdirSync(directory, { withFileTypes: true })
  } catch {
    watcher?.close()
    return
  }
  watcher.on('error', () => unwatchDirectory(directory))
  directoryWatchers.set(directory, watcher)
  for (const entry of entries) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) {
      if (!IGNORED_DIRECTORIES.has(entry.name)) watchDirectory(path, reportExistingFiles)
    } else if (reportExistingFiles) {
      queueFileChange(path, FILE_CREATED)
    }
  }
}

function unwatchDirectory(directory) {
  for (const [path, watcher] of directoryWatchers) {
    if (path === directory || path.startsWith(directory + '/')) {
      watcher.close()
      directoryWatchers.delete(path)
    }
  }
}

function onFileEvent(directory, eventType, filename) {
  if (filename === null || IGNORED_DIRECTORIES.has(filename)) return
  const path = join(directory, filename)
  const stats = statOrUndefined(path)
  if (stats === undefined) {
    unwatchDirectory(path)
    queueFileChange(path, FILE_DELETED)
  } else if (stats.isDirectory()) {
    // Files written before the new directory got watched would be missed
    watchDirectory(path, true)
  } else {
    queueFileChange(path, eventType === 'rename' ? FILE_CREATED : FILE_CHANGED)
  }
}

function queueFileChange(path, type) {
  const previous = pendingFileChanges.get(path)
  pendingFileChanges.set(path, previous === FILE_CREATED && type === FILE_CHANGED ? FILE_CREATED : type)
  fileChangeTimer ??= setTimeout(flushFileChanges, FILE_CHANGE_BATCH_MS)
}

function flushFileChanges() {
  fileChangeTimer = undefined
  const changes = [...pendingFileChanges].map(([path, type]) => ({ uri: pathToFileURL(path).href, type }))
  pendingFileChanges.clear()
  if (watchRegistrations.size === 0 || changes.length === 0) return
  toServer({ jsonrpc: '2.0', method: WATCHED_FILES_METHOD, params: { changes } })
  schedulePullAll()
}

// Answers tsgo's file watcher (un)registrations, forwarding any others to
// kak-lsp. Returns whether the message was fully handled.
function handleWatchRegistration(message, listKey) {
  const registrations = message.params[listKey]
  const watched = registrations.filter((registration) => registration.method === WATCHED_FILES_METHOD)
  if (watched.length === 0) return false

  for (const { id } of watched) {
    if (message.method === 'client/registerCapability') watchRegistrations.add(id)
    else watchRegistrations.delete(id)
  }
  if (watchRegistrations.size > 0 && directoryWatchers.size === 0 && workspaceRoot) {
    watchDirectory(workspaceRoot, false)
  }

  const others = registrations.filter((registration) => registration.method !== WATCHED_FILES_METHOD)
  if (others.length > 0) {
    message.params[listKey] = others
    return false
  }
  toServer({ jsonrpc: '2.0', id: message.id, result: null })
  return true
}

// Message routing

readMessages(process.stdin, (message) => {
  const uri = message.params?.textDocument?.uri
  switch (message.method) {
    case 'initialize':
      initializeRequestId = message.id
      initialize(message.params)
      break
    case 'textDocument/didOpen':
      openDocuments.add(uri)
      schedulePull(uri)
      break
    case 'textDocument/didChange':
      schedulePull(uri)
      break
    case 'textDocument/didSave':
      schedulePullAll()
      break
    case 'textDocument/didClose':
      openDocuments.delete(uri)
      clearTimeout(pullTimers.get(uri))
      pullTimers.delete(uri)
      latestPullByUri.delete(uri)
      break
  }
  toServer(message)
})

readMessages(server.stdout, (message) => {
  if (message.id === initializeRequestId && message.method === undefined) {
    serverPullsDiagnostics = Boolean(message.result?.capabilities?.diagnosticProvider)
  }
  if (pendingPulls.has(message.id) && message.method === undefined) {
    const uri = pendingPulls.get(message.id)
    pendingPulls.delete(message.id)
    handlePullResponse(uri, message)
    return
  }
  switch (message.method) {
    case 'workspace/diagnostic/refresh':
      toServer({ jsonrpc: '2.0', id: message.id, result: null })
      schedulePullAll()
      return
    case 'client/registerCapability':
      if (handleWatchRegistration(message, 'registrations')) return
      break
    case 'client/unregisterCapability':
      // "unregisterations" is the LSP spec's spelling
      if (handleWatchRegistration(message, 'unregisterations')) return
      break
  }
  toEditor(message)
})

process.stdin.on('end', () => server.stdin.end())
for (const signal of ['SIGTERM', 'SIGINT', 'SIGHUP']) {
  process.on(signal, () => server.kill(signal))
}
server.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)))
