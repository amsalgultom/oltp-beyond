'use client'

import { useEffect, useState } from 'react'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

interface FunnelLevel {
  level: number
  contracts: number
  pct_of_total: number
}

export default function FunnelPage() {
  const [data, setData] = useState<FunnelLevel[]>([])
  const [steps, setSteps] = useState<string[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('/api/funnel')
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        const result = await response.json()
        setData(result.data || [])
        setSteps(result.steps || [])
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch funnel data')
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [])

  return (
    <div>
      <h2 className="page-title">Collection Funnel</h2>
      <p className="page-subtitle">7-day conversion funnel: Task → Called → Answered → PTP → Paid</p>

      {error && <div className="error">Error: {error}</div>}

      <div className="grid">
        <div className="card">
          <div className="card-title">Funnel Levels</div>
          {loading ? (
            <div className="loading">Loading...</div>
          ) : data.length > 0 ? (
            <div>
              <table>
                <thead>
                  <tr>
                    <th>Stage</th>
                    <th>Contracts</th>
                    <th>% of Total</th>
                  </tr>
                </thead>
                <tbody>
                  {data.map((row, idx) => (
                    <tr key={idx}>
                      <td>{row.level === 0 ? 'Start' : steps[row.level - 1] || `Step ${row.level}`}</td>
                      <td>{row.contracts}</td>
                      <td>{row.pct_of_total}%</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="loading">No data available</div>
          )}
        </div>

        <div className="card">
          <div className="card-title">Funnel Chart</div>
          {data.length > 0 ? (
            <div className="chart-container">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data.slice(0, 5)}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="level" stroke="#7f8c8d" />
                  <YAxis stroke="#7f8c8d" />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="contracts" fill="#3498db" name="Contracts" />
                  <Bar dataKey="pct_of_total" fill="#27ae60" name="% of Total" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <div className="loading">Loading chart...</div>
          )}
        </div>
      </div>
    </div>
  )
}
