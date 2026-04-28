import { useState, useEffect, useCallback } from 'react'
import Header from './components/Header.jsx'
import ProductsTab from './components/ProductsTab.jsx'
import OrdersTab from './components/OrdersTab.jsx'
import UsersTab from './components/UsersTab.jsx'
import Toast from './components/Toast.jsx'

export default function App() {
  const [tab, setTab] = useState('products')
  const [health, setHealth] = useState({ products: 'checking', users: 'checking', orders: 'checking' })
  const [toast, setToast] = useState(null)

  const showToast = useCallback((msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3500)
  }, [])

  // Poll service health every 30s
  useEffect(() => {
    const check = async () => {
      const checks = [
        { key: 'products', url: '/products' },
        { key: 'users',    url: '/users/health' },
        { key: 'orders',   url: '/orders/health' },
      ]
      for (const { key, url } of checks) {
        try {
          const res = await fetch(url, { signal: AbortSignal.timeout(4000) })
          // 2xx or 4xx means service is up; 5xx or timeout means down
          setHealth(h => ({ ...h, [key]: res.status < 500 ? 'up' : 'degraded' }))
        } catch {
          setHealth(h => ({ ...h, [key]: 'down' }))
        }
      }
    }
    check()
    const id = setInterval(check, 30000)
    return () => clearInterval(id)
  }, [])

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Header tab={tab} setTab={setTab} health={health} />

      <main style={{ flex: 1, maxWidth: 1200, margin: '0 auto', padding: '32px 24px', width: '100%' }}>
        {tab === 'products' && <ProductsTab showToast={showToast} />}
        {tab === 'orders'   && <OrdersTab   showToast={showToast} />}
        {tab === 'users'    && <UsersTab    showToast={showToast} />}
      </main>

      {toast && <Toast msg={toast.msg} type={toast.type} />}
    </div>
  )
}
