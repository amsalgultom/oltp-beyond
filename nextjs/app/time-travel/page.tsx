'use client'

import { useEffect, useState } from 'react'
import { format, subDays } from 'date-fns'

interface CustomerState {
  no_kontrak: string
  customer_name: string
  phone_number: string
  call_status: string
  priority: number
  overdue: number
  out_std_pkk: number
  is_paid: number
  current_agent: string
}

export default function TimeTravelPage() {
  const [selectedDate, setSelectedDate] = useState(format(subDays(new Date(), 1), 'yyyy-MM-dd'))
  const [data, setData] = useState<CustomerState[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const fetchData = async (date: string) => {
    setLoading(true)
    try {
      const response = await fetch(`/api/timetravel?asof=${date}`)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const result = await response.json()
      setData(result.data || [])
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch data')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchData(selectedDate)
  }, [selectedDate])

  return (
    <div>
      <h2 className="page-title">Time Travel</h2>
      <p className="page-subtitle">View customer queue state at a specific point in time</p>

      {error && <div className="error">Error: {error}</div>}

      <div className="card">
        <div className="card-title">Select Date</div>
        <div style={{ marginBottom: '1rem' }}>
          <label htmlFor="date-picker">Date: </label>
          <input
            id="date-picker"
            type="date"
            value={selectedDate}
            onChange={(e) => setSelectedDate(e.target.value)}
            style={{ marginLeft: '0.5rem' }}
          />
        </div>

        <div className="card-title">Queue State as of {selectedDate} 23:59:59</div>
        {loading ? (
          <div className="loading">Loading...</div>
        ) : data.length > 0 ? (
          <table>
            <thead>
              <tr>
                <th>Contract #</th>
                <th>Customer</th>
                <th>Phone</th>
                <th>Status</th>
                <th>Priority</th>
                <th>Overdue (d)</th>
                <th>Outstanding (Rp)</th>
                <th>Paid?</th>
                <th>Agent</th>
              </tr>
            </thead>
            <tbody>
              {data.slice(0, 100).map((row, idx) => (
                <tr key={idx}>
                  <td>{row.no_kontrak}</td>
                  <td>{row.customer_name}</td>
                  <td>{row.phone_number}</td>
                  <td>{row.call_status}</td>
                  <td>{row.priority}</td>
                  <td>{row.overdue}</td>
                  <td>{row.out_std_pkk ? `Rp ${(row.out_std_pkk / 1000000).toFixed(2)}M` : '0'}</td>
                  <td>{row.is_paid ? 'Yes' : 'No'}</td>
                  <td>{row.current_agent || '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <div className="loading">No data for this date</div>
        )}
      </div>
    </div>
  )
}
