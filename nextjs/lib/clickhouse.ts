import { createClient } from '@clickhouse/client'

let client: any = null

export function getClickHouseClient() {
  if (client) return client

  const url = process.env.CLICKHOUSE_URL
  const user = process.env.CLICKHOUSE_USER
  const password = process.env.CLICKHOUSE_PASSWORD

  if (!url || !user || !password) {
    throw new Error('Missing ClickHouse connection variables in env')
  }

  client = createClient({
    url: url,
    username: user,
    password: password,
    database: 'collection',
    clickhouse_settings: {
      max_execution_time: 30,
    },
  })

  return client
}

export async function queryClickHouse(query: string, params?: Record<string, any>) {
  const ch = getClickHouseClient()
  const result = await ch.query({
    query: query,
    query_params: params || {},
    format: 'JSONEachRow',
  })
  return await result.json()
}
