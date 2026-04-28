export default function Toast({ msg, type }) {
  return (
    <div className={`toast toast-${type}`}>
      {type === 'success' ? '✓ ' : '✕ '}{msg}
    </div>
  )
}
