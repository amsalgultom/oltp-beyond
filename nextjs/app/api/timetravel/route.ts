import { queryClickHouse } from '@/lib/clickhouse'
import { NextResponse, NextRequest } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const asof = request.nextUrl.searchParams.get('asof') || '2026-05-15'

    if (!/^\d{4}-\d{2}-\d{2}$/.test(asof)) {
      return NextResponse.json(
        { error: 'Invalid date format, use YYYY-MM-DD' },
        { status: 400 }
      )
    }

    const query = `
      WITH asof_ts AS (
        SELECT toUnixTimestamp64Milli(toDateTime(\`${asof} 23:59:59\`, 'UTC')) AS ts_ms
      ),
      state_asof AS (
        SELECT
          id,
          no_kontrak,
          customer_name,
          phone_number,
          call_status,
          priority,
          overdue,
          out_std_pkk,
          is_paid,
          payment_date,
          marked_by,
          kode_cabang,
          argMax(call_status, _ts_ms) AS final_call_status,
          argMax(overdue, _ts_ms) AS final_overdue,
          argMax(is_paid, _ts_ms) AS final_is_paid,
          argMax(marked_by, _ts_ms) AS final_marked_by,
          argMax(_is_deleted, _ts_ms) AS final_is_deleted
        FROM customer_id_raw, asof_ts
        WHERE _ts_ms <= asof_ts.ts_ms
        GROUP BY id, no_kontrak, customer_name, phone_number, call_status, priority, overdue, out_std_pkk, is_paid, payment_date, marked_by, kode_cabang
      )
      SELECT
        no_kontrak,
        customer_name,
        phone_number,
        final_call_status AS call_status,
        priority,
        final_overdue AS overdue,
        out_std_pkk,
        final_is_paid AS is_paid,
        final_marked_by AS current_agent
      FROM state_asof
      WHERE final_is_deleted = 0
      ORDER BY priority, final_overdue DESC
      LIMIT 1000
    `

    const data = await queryClickHouse(query)

    return NextResponse.json({
      asof_date: asof,
      data: data || [],
    })
  } catch (error) {
    console.error('Time Travel API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch time travel data' },
      { status: 500 }
    )
  }
}
