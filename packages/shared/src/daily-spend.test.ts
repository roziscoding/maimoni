import { describe, expect, test } from 'bun:test'
import type { DailySpend } from './schemas'
import { dailySpendInput, groupDailySpends } from './daily-spend'

const spend = (id: string, day: number, createdAt: string): DailySpend => ({
  id,
  monthId: '00000000-0000-0000-0000-000000000001',
  day,
  currency: 'EUR',
  amount: 10,
  expression: null,
  note: null,
  createdAt,
})

describe('dailySpendInput', () => {
  test('normalizes an expression and description into a daily spend', () => {
    // Arrange
    const draft = { day: 2, currency: 'BRL' as const, amountText: '=10,50+2', note: ' mercado ' }

    // Act
    const input = dailySpendInput(draft)

    // Assert
    expect(input).toEqual({ day: 2, currency: 'BRL', amount: 12.5, expression: '10,50+2', note: 'mercado' })
  })

  test('keeps a plain amount and converts an empty description to null', () => {
    // Arrange
    const draft = { day: 6, currency: 'EUR' as const, amountText: '12,50', note: '  ' }

    // Act
    const input = dailySpendInput(draft)

    // Assert
    expect(input).toEqual({ day: 6, currency: 'EUR', amount: 12.5, expression: null, note: null })
  })

  test('rejects an invalid amount', () => {
    // Arrange
    const draft = { day: 1, currency: 'EUR' as const, amountText: 'abc', note: '' }

    // Act
    const input = dailySpendInput(draft)

    // Assert
    expect(input).toBeNull()
  })
})

describe('groupDailySpends', () => {
  test('groups expenses by day with the most recent day first', () => {
    // Arrange
    const spends = [
      spend('a', 2, '2026-10-02T09:00:00.000Z'),
      spend('b', 7, '2026-10-07T10:00:00.000Z'),
      spend('c', 2, '2026-10-02T08:00:00.000Z'),
    ]

    // Act
    const groups = groupDailySpends(spends)

    // Assert
    expect(groups.map(group => ({ day: group.day, ids: group.spends.map(item => item.id) }))).toEqual([
      { day: 7, ids: ['b'] },
      { day: 2, ids: ['c', 'a'] },
    ])
  })
})
