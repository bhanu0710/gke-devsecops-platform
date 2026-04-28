const dotClass = (status) => {
  if (status === 'up')       return 'dot dot-green'
  if (status === 'degraded') return 'dot dot-yellow'
  if (status === 'down')     return 'dot dot-red'
  return 'dot dot-gray'
}

const TABS = [
  { id: 'products', label: '📦 Products' },
  { id: 'orders',   label: '🛒 Orders'   },
  { id: 'users',    label: '👤 Users'    },
]

export default function Header({ tab, setTab, health }) {
  return (
    <header style={{
      background: 'var(--surface)',
      borderBottom: '1px solid var(--border)',
      position: 'sticky', top: 0, zIndex: 50,
    }}>
      {/* Top bar */}
      <div style={{
        maxWidth: 1200, margin: '0 auto', padding: '0 24px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        height: 56,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontSize: 22 }}>🛡️</span>
          <div>
            <div style={{ fontWeight: 700, fontSize: 15, letterSpacing: '-0.02em' }}>
              DevSecOps Platform
            </div>
            <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>GKE · staging</div>
          </div>
        </div>

        {/* Service health indicators */}
        <div style={{ display: 'flex', gap: 16 }}>
          {['products', 'users', 'orders'].map(svc => (
            <div key={svc} style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
              <span className={dotClass(health[svc])} />
              <span style={{ color: 'var(--text-muted)', fontSize: 12, textTransform: 'capitalize' }}>{svc}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Tab bar */}
      <div style={{
        maxWidth: 1200, margin: '0 auto', padding: '0 24px',
        display: 'flex', gap: 4, borderTop: '1px solid var(--border)',
      }}>
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            style={{
              padding: '10px 16px',
              background: 'transparent',
              color: tab === t.id ? 'var(--accent-hover)' : 'var(--text-muted)',
              borderBottom: tab === t.id ? '2px solid var(--accent)' : '2px solid transparent',
              fontWeight: tab === t.id ? 600 : 400,
              borderRadius: 0,
              fontSize: 13,
            }}
          >
            {t.label}
          </button>
        ))}
      </div>
    </header>
  )
}
