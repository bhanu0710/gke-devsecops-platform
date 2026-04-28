import { useState } from 'react'

export default function UsersTab({ showToast }) {
  const [mode, setMode] = useState('register') // 'register' | 'login'
  const [form, setForm] = useState({ name: '', email: '', password: '' })
  const [loading, setLoading] = useState(false)
  const [lastUser, setLastUser] = useState(null)
  const [lastToken, setLastToken] = useState(null)

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }))

  const register = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const res = await fetch('/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || JSON.stringify(data))
      setLastUser(data)
      showToast(`User created! ID: ${data.id}`)
      setForm({ name: '', email: '', password: '' })
    } catch (err) {
      showToast(err.message, 'error')
    } finally {
      setLoading(false)
    }
  }

  const login = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const res = await fetch('/users/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: form.email, password: form.password }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Login failed')
      setLastToken(data.token)
      setLastUser(data.user)
      showToast('Logged in successfully')
    } catch (err) {
      showToast(err.message, 'error')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ maxWidth: 480 }}>
      <h2 style={{ fontSize: 20, fontWeight: 700, marginBottom: 24 }}>👤 User Management</h2>

      {/* Mode toggle */}
      <div style={{ display: 'flex', gap: 0, marginBottom: 24, background: 'var(--surface2)', borderRadius: 10, padding: 4, width: 'fit-content' }}>
        {['register', 'login'].map(m => (
          <button key={m} onClick={() => setMode(m)} style={{
            padding: '7px 20px', borderRadius: 8, background: mode === m ? 'var(--accent)' : 'transparent',
            color: mode === m ? '#fff' : 'var(--text-muted)', fontWeight: mode === m ? 600 : 400, textTransform: 'capitalize',
          }}>
            {m === 'register' ? '✦ Register' : '→ Login'}
          </button>
        ))}
      </div>

      <div className="card">
        <form onSubmit={mode === 'register' ? register : login}>
          {mode === 'register' && (
            <div className="form-group">
              <label>Name</label>
              <input value={form.name} onChange={e => set('name', e.target.value)} placeholder="Bhanu Pratap Singh" required />
            </div>
          )}
          <div className="form-group">
            <label>Email</label>
            <input type="email" value={form.email} onChange={e => set('email', e.target.value)} placeholder="bhanu@example.com" required />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input type="password" value={form.password} onChange={e => set('password', e.target.value)} placeholder="••••••••" required minLength={6} />
          </div>
          <button type="submit" className="btn btn-primary" style={{ width: '100%', marginTop: 8 }} disabled={loading}>
            {loading ? '…' : mode === 'register' ? 'Create Account' : 'Login'}
          </button>
        </form>
      </div>

      {/* Last result */}
      {lastUser && (
        <div className="card" style={{ marginTop: 20, background: 'var(--surface2)' }}>
          <div style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 10, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            {lastToken ? 'Logged in as' : 'Created user'}
          </div>
          <div style={{ fontWeight: 600 }}>{lastUser.name || lastUser.email}</div>
          <div style={{ fontFamily: 'monospace', fontSize: 12, color: 'var(--accent-hover)', marginTop: 6, wordBreak: 'break-all' }}>
            ID: {lastUser.id}
          </div>
          {lastToken && (
            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 4 }}>JWT Token (use in Orders tab):</div>
              <div style={{
                fontFamily: 'monospace', fontSize: 11, color: 'var(--text-muted)',
                background: 'var(--bg)', padding: 10, borderRadius: 6,
                wordBreak: 'break-all', maxHeight: 80, overflow: 'auto',
              }}>
                {lastToken}
              </div>
              <button className="btn btn-ghost btn-sm" style={{ marginTop: 8 }}
                onClick={() => { navigator.clipboard.writeText(lastToken); showToast('Token copied!') }}>
                Copy Token
              </button>
            </div>
          )}
          <div style={{ marginTop: 12, padding: '8px 12px', background: 'rgba(99,102,241,0.1)', borderRadius: 6, fontSize: 12, color: 'var(--accent-hover)' }}>
            💡 Copy this ID to use in the Orders tab → Place Order
          </div>
        </div>
      )}
    </div>
  )
}
