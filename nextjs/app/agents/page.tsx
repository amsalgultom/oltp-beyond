'use client'

import { useEffect, useState } from 'react'
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

interface AgentProductivity {
  work_date: string
  agent_username: string
  tasks: number
  calls: number
  answered: number
  ptp: number
  talk_minutes: number
  connect_rate_pct: number
  ptp_rate_pct: number
}

export default function AgentsPage() {
  const [data, setData] = useState<AgentProductivity[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('/api/preagg')
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        const result = await response.json()
        setData(result.agent_productivity || [])
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch agent data')
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [])

  return (
    <div>
      <h2 className="page-title">Agent Productivity</h2>
      <p className="page-subtitle">Daily performance metrics (last 30 days)</p>

      {error && <div className="error">Error: {error}</div>}

      <div className="grid">
        <div className="card" style={{ gridColumn: '1 / -1' }}>
          <div className="card-title">Agent Performance Table</div>
          {loading ? (
            <div className="loading">Loading...</div>
          ) : data.length > 0 ? (
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Agent</th>
                  <th>Tasks</th>
                  <th>Calls</th>
                  <th>Answered</th>
                  <th>PTP</th>
                  <th>Talk (min)</th>
                  <th>Connect %</th>
                  <th>PTP %</th>
                </tr>
              </thead>
              <tbody>
                {data.slice(0, 50).map((row, idx) => (
                  <tr key={idx}>
                    <td>{row.work_date}</td>
                    <td>{row.agent_username}</td>
                    <td>{row.tasks}</td>
                    <td>{row.calls}</td>
                    <td>{row.answered}</td>
                    <td>{row.ptp}</td>
                    <td>{row.talk_minutes}</td>
                    <td>{row.connect_rate_pct}%</td>
                    <td>{row.ptp_rate_pct}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <div className="loading">No data available</div>
          )}
        </div>

        {data.length > 0 && (
          <div className="card" style={{ gridColumn: '1 / -1' }}>
            <div className="card-title">Calls by Agent (Recent)</div>
            <div className="chart-container">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data.slice(0, 20)}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis
                    dataKey="agent_username"
                    angle={-45}
                    textAnchor="end"
                    height={100}
                    stroke="#7f8c8d"
                  />
                  <YAxis stroke="#7f8c8d" />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="calls" fill="#3498db" name="Calls" />
                  <Bar dataKey="answered" fill="#27ae60" name="Answered" />
                  <Bar dataKey="ptp" fill="#e74c3c" name="PTP" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
