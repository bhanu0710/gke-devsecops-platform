import { useState, useEffect } from 'react'

const CATEGORY_COLORS = {
  electronics: '#6366f1', appliances: '#22c55e', clothing: '#f59e0b',
  books: '#06b6d4', food: '#ec4899', misc: '#94a3b8',
}

function ProductCard({ product, onOrder }) {
  const color = CATEGORY_COLORS[product.category] || '#94a3b8'
  return (
    <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
      <div style={{
        height: 80, borderRadius: 8, background: `${color}18`,
        border: `1px solid ${color}30`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 32,
      }}>
        {product.category === 'electronics' ? '💻'
          : product.category === 'appliances' ? '🏠'
          : product.category === 'clothing' ? '👕'
          : product.category === 'books' ? '📚'
          : product.category === 'food' ? '🍕' : '📦'}
      </div>

      <div>
        <div style={{ fontWeight: 600, fontSize: 15, marginBottom: 4 }}>{product.name}</div>
        <span className="badge" style={{ background: `${color}18`, color }}>
          {product.category}
        </span>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 'auto' }}>
        <div>
          <div style={{ fontSize: 20, fontWeight: 700, color: 'var(--accent-hover)' }}>
            ${product.price.toFixed(2)}
          </div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
            {product.stock} in stock
          </div>
        </div>
        <button className="btn btn-primary btn-sm" onClick={() => onOrder(product)}>
          Order
        </button>
      </div>
    </div>
  )
}

function AddProductModal({ onClose, onAdd }) {
  const [form, setForm] = useState({ name: '', price: '', category: 'electronics', stock: '100' })
  const [loading, setLoading] = useState(false)

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }))

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const res = await fetch('/products', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...form, price: parseFloat(form.price), stock: parseInt(form.stock) }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.detail || 'Failed')
      onAdd(data)
    } catch (err) {
      alert(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <h2>➕ Add Product</h2>
        <form onSubmit={submit}>
          <div className="form-group">
            <label>Name</label>
            <input value={form.name} onChange={e => set('name', e.target.value)} placeholder="e.g. MacBook Pro" required />
          </div>
          <div className="form-group">
            <label>Price ($)</label>
            <input type="number" step="0.01" min="0.01" value={form.price} onChange={e => set('price', e.target.value)} placeholder="99.99" required />
          </div>
          <div className="form-group">
            <label>Category</label>
            <select value={form.category} onChange={e => set('category', e.target.value)}>
              {['electronics','appliances','clothing','books','food','misc'].map(c => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>
          <div className="form-group">
            <label>Stock</label>
            <input type="number" min="0" value={form.stock} onChange={e => set('stock', e.target.value)} required />
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 8 }}>
            <button type="button" className="btn btn-ghost" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Adding…' : 'Add Product'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function OrderModal({ product, onClose, onOrder }) {
  const [form, setForm] = useState({ userId: '', quantity: '1' })
  const [loading, setLoading] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const res = await fetch('/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: form.userId, productId: product.id, quantity: parseInt(form.quantity) }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Failed')
      onOrder(data)
    } catch (err) {
      alert(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <h2>🛒 Place Order</h2>
        <div className="card" style={{ marginBottom: 20, padding: '12px 16px', background: 'var(--surface2)' }}>
          <div style={{ fontWeight: 600 }}>{product.name}</div>
          <div style={{ color: 'var(--accent-hover)', fontWeight: 700, marginTop: 4 }}>
            ${product.price.toFixed(2)} × {form.quantity} = ${(product.price * (parseInt(form.quantity)||0)).toFixed(2)}
          </div>
        </div>
        <form onSubmit={submit}>
          <div className="form-group">
            <label>User ID</label>
            <input value={form.userId} onChange={e => setForm(f => ({...f, userId: e.target.value}))}
              placeholder="Enter your user ID" required />
            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>
              Create a user in the Users tab first
            </div>
          </div>
          <div className="form-group">
            <label>Quantity</label>
            <input type="number" min="1" max={product.stock} value={form.quantity}
              onChange={e => setForm(f => ({...f, quantity: e.target.value}))} required />
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end', marginTop: 8 }}>
            <button type="button" className="btn btn-ghost" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Placing…' : 'Place Order'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function ProductsTab({ showToast }) {
  const [products, setProducts]     = useState([])
  const [loading, setLoading]       = useState(true)
  const [error, setError]           = useState(null)
  const [showAdd, setShowAdd]       = useState(false)
  const [orderProduct, setOrderProduct] = useState(null)
  const [search, setSearch]         = useState('')
  const [category, setCategory]     = useState('all')

  useEffect(() => {
    fetch('/products')
      .then(r => r.json())
      .then(d => { setProducts(d.products || []); setLoading(false) })
      .catch(() => { setError('Could not reach product-service'); setLoading(false) })
  }, [])

  const categories = ['all', ...new Set(products.map(p => p.category))]

  const filtered = products.filter(p =>
    (category === 'all' || p.category === category) &&
    p.name.toLowerCase().includes(search.toLowerCase())
  )

  if (loading) return <div style={{ color: 'var(--text-muted)', padding: 40, textAlign: 'center' }}>Loading products…</div>
  if (error)   return <div style={{ color: 'var(--danger)', padding: 40, textAlign: 'center' }}>{error}</div>

  return (
    <div>
      {/* Toolbar */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap', alignItems: 'center' }}>
        <input
          style={{ maxWidth: 240 }}
          placeholder="🔍  Search products…"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
        <select style={{ maxWidth: 160 }} value={category} onChange={e => setCategory(e.target.value)}>
          {categories.map(c => <option key={c} value={c}>{c === 'all' ? 'All categories' : c}</option>)}
        </select>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 8, alignItems: 'center' }}>
          <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>{filtered.length} products</span>
          <button className="btn btn-primary" onClick={() => setShowAdd(true)}>+ Add Product</button>
        </div>
      </div>

      {/* Grid */}
      {filtered.length === 0
        ? <div style={{ textAlign: 'center', color: 'var(--text-muted)', padding: 60 }}>No products found</div>
        : <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 16 }}>
            {filtered.map(p => (
              <ProductCard key={p.id} product={p} onOrder={setOrderProduct} />
            ))}
          </div>
      }

      {showAdd && (
        <AddProductModal
          onClose={() => setShowAdd(false)}
          onAdd={p => {
            setProducts(ps => [...ps, p])
            setShowAdd(false)
            showToast(`"${p.name}" added successfully`)
          }}
        />
      )}

      {orderProduct && (
        <OrderModal
          product={orderProduct}
          onClose={() => setOrderProduct(null)}
          onOrder={order => {
            setOrderProduct(null)
            showToast(`Order placed! Total: $${order.total.toFixed(2)}`)
          }}
        />
      )}
    </div>
  )
}
