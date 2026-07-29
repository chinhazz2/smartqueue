import { useEffect, useState } from 'react'

type ApiHealth = {
  service: string
  status: string
  timestamp: string
}

function App() {
  const [health, setHealth] = useState<ApiHealth | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    async function loadHealth() {
      try {
        const response = await fetch('/api/health')

        if (!response.ok) {
          throw new Error(`Backend returned HTTP ${response.status}`)
        }

        const data = (await response.json()) as ApiHealth
        setHealth(data)
      } catch (caughtError) {
        const message =
          caughtError instanceof Error
            ? caughtError.message
            : 'Unknown error'

        setError(message)
      }
    }

    void loadHealth()
  }, [])

  return (
    <main>
      <h1>SmartQueue</h1>
      <p>Appointment and queue management system</p>

      <section>
        <h2>System status</h2>

        {!health && !error && <p>Checking backend...</p>}

        {health && (
          <>
            <p>
              API status: <strong>{health.status}</strong>
            </p>
            <p>Service: {health.service}</p>
            <p>Checked at: {health.timestamp}</p>
          </>
        )}

        {error && (
          <p role="alert">
            Cannot reach backend: {error}
          </p>
        )}
      </section>
    </main>
  )
}

export default App