import { useState } from 'react'

const STATUS_COLORS = { pending: 'yellow', processing: 'gray', shipped: 'green', delivered: 'green', cancelled: 'red' }

export default function OrdersTab({ showToast }) {
  const [form, setForm] = useState({ userId: '', productId: '', quantity: '1' })
  const [loading, setLoading] = useState(false)
  const [orders, setOrders] = useState([])
  const [lookupId, setLookupId] = useState('')
  const [lookupResult, setLookupResult] = useState(null)

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }))

  const placeOrder = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const res = await fetch('/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...form, quantity: parseInt(form.quantity) }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Failed to place order')
      setOrders(prev => [data, ...prev])
      showToast(`Order #${data.id.slice(0,8)} placed! Total: $${data.total.toFixed(2)}`)
      setForm({ userId: form.userId, productId: '', quantity: '1' })
    } catch (err) {
      showToast(err.message, 'error')
    } finally {
      setLoading(false)
    }
  }

  const lookupOrder = async () => {
    if (!lookupId.trim()) return
    try {
      const res = await fetch(`/orders/${lookupId.trim()}`)
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Not found')
      setLookupResult(data)
    } catch (err) {
      showToast(err.message, 'error')
      setLookupResult(null)
    }
  }

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, alignItems: 'start' }}>

      {/* Place order */}
      <div>
        <h2 style={{ fontSize: 20, fontWeight: 700, marginBottom: 20 }}>🛒 Place Order</h2>
        <div className="card">
          <form onSubmit={placeOrder}>
            <div className="form-group">
              <label>User ID</label>
              <input value={form.userId} onChange={e => set('userId', e.target.value)}
                placeholder="Get from Users tab" required />
            </div>
            <div className="form-group">
              <label>Product ID</label>
              <input value={form.productId} onChange={e => set('productId', e.target.value)}
                placeholder="Get from Products tab → hover card" required />
            </div>
            <div className="form-group">
              <label>Quantity</label>
              <input type="number" min="1" value={form.quantity}
                onChange={e => set('quantity', e.target.value)} required />
            </div>
            <button type="submit" className="btn btn-primary" style={{ width: '100%', marginTop: 8 }} disabled={loading}>
              {loading ? 'Placing…' : 'Place Order'}
            </button>
          </form>
        </div>

        {/* Lookup */}
        <div style={{ marginTop: 24 }}>
          <h3 style={{ fontSize: 15, fontWeight: 600, marginBottom: 12 }}>🔍 Look up order</h3>
          <div style={{ display: 'flex', gap: 8 }}>
            <input value={lookupId} onChange={e => setLookupId(e.target.value)}
              placeholder="Order ID…" onKeyDown={e => e.key === 'Enter' && lookupOrder()} />
            <button className="btn btn-ghost" onClick={lookupOrder} style={{ whiteSpace: 'nowrap' }}>Look up</button>
          </div>
          {lookupResult && (
            <div className="card" style={{ marginTop: 12, background: 'var(--surface2)' }}>
              <OrderRow order={lookupResult} />
            </div>
          )}
        </div>
      </div>

      {/* Recent orders */}
      <div>
        <h2 style={{ fontSize: 20, fontWeight: 700, marginBottom: 20 }}>
          Recent Orders
          <span style={{ fontSize: 13, fontWeight: 400, color: 'var(--text-muted)', marginLeft: 8 }}>
            (this session)
          </span>
        </h2>
        {orders.length === 0
          ? <div className="card" style={{ textAlign: 'center', color: 'var(--text-muted)', padding: 40 }}>
              No orders yet — place your first one →
            </div>
          : <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {orders.map(o => (
                <div key={o.id} className="card" style={{ padding: '14px 16px' }}>
                  <OrderRow order={o} />
                </div>
              ))}
            </div>
        }
      </div>
    </div>
  )
}

function OrderRow({ order }) {
  const color = STATUS_COLORS[order.status] || 'gray'
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontFamily: 'monospace', fontSize: 12, color: 'var(--text-muted)' }}>
          #{order.id.slice(0, 12)}…
        </span>
        <span className={`badge badge-${color}`}>
          <span className={`dot dot-${color}`} /> {order.status}
        </span>
      </div>
      <div style={{ marginTop: 8, display: 'flex', gap: 20, fontSize: 13 }}>
        <span>Qty: <strong>{order.quantity}</strong></span>
        <span>Total: <strong style={{ color: 'var(--accent-hover)' }}>${order.total?.toFixed(2)}</strong></span>
        <span style={{ color: 'var(--text-muted)', fontSize: 12 }}>
          {new Date(order.createdAt).toLocaleTimeString()}
        </span>
      </div>
    </div>
  )
}
