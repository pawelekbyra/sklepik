import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const E2E_DIR = dirname(fileURLToPath(import.meta.url))
export const CREDENTIALS_FILE = resolve(E2E_DIR, '.credentials.json')
export const RAILS_PID_FILE = resolve(E2E_DIR, '.rails.pid')
// Pre-seeds the admin UI language to English so the English-worded specs
// (getByLabel(/email/i), getByText(/welcome back/i)) match — the panel
// otherwise boots in Polish (DEFAULT_ADMIN_LOCALE), whose 'E-mail' label
// doesn't satisfy /email/i.
export const STORAGE_STATE_FILE = resolve(E2E_DIR, '.storage-state.json')
