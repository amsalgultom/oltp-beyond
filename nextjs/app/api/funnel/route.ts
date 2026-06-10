import { queryClickHouse } from '@/lib/clickhouse'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET() {
  try {
    const query = `
      WITH events AS (
        SELECT
          no_kontrak,
          created_ts AS ts,
          1 AS step
        FROM collection_task FINAL
        WHERE _is_deleted = 0 AND created_ts >= now() - INTERVAL 7 DAY

        UNION ALL
        SELECT
          contract_no,
          calldate,
          2
        FROM cdr FINAL
        WHERE _is_deleted = 0 AND calldate >= now() - INTERVAL 7 DAY AND contract_no != ''

        UNION ALL
        SELECT
          contract_no,
          calldate,
          3
        FROM cdr FINAL
        WHERE _is_deleted = 0 AND disposition = 'ANSWERED' AND calldate >= now() - INTERVAL 7 DAY AND contract_no != ''

        UNION ALL
        SELECT
          no_kontrak,
          created_ts,
          4
        FROM collection_result FINAL
        WHERE _is_deleted = 0 AND classification = 'PTP' AND created_ts >= now() - INTERVAL 7 DAY

        UNION ALL
        SELECT
          no_kontrak,
          toDateTime64(payment_date, 3),
          5
        FROM customer_id FINAL
        WHERE _is_deleted = 0 AND is_paid = 1 AND payment_date >= toDate(now() - INTERVAL 7 DAY)
      )

      SELECT
        level,
        count() AS contracts,
        round(100.0 * contracts / (SELECT count() FROM (SELECT DISTINCT no_kontrak FROM events WHERE step = 1)), 1) AS pct_of_total
      FROM (
        SELECT
          no_kontrak,
          windowFunnel(604800)(ts, step = 1, step = 2, step = 3, step = 4, step = 5) AS level
        FROM events
        GROUP BY no_kontrak
      )
      GROUP BY level
      ORDER BY level
    `

    const data = await queryClickHouse(query)

    return NextResponse.json({
      data: data || [],
      steps: ['Task Created', 'Called', 'Answered', 'PTP', 'Paid'],
    })
  } catch (error) {
    console.error('Funnel API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch funnel data' },
      { status: 500 }
    )
  }
}
