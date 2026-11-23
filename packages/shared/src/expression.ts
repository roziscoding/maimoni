/**
 * Evaluates the small arithmetic expressions the spreadsheet used inside value cells
 * (e.g. `=11.99+2.99` or `20000.5+509.54`). Supports + - * / and parentheses. Numbers can be written
 * as `1250.99`, `1250,99`, `2.500` or pt-BR style `1.250,99`; currency symbols are ignored. Returns `null` for anything else.
 */
export function evaluateExpression(input: string): number | null {
  const source = input.trim().replace(/^=/, '').replace(/R\$|\p{Sc}|\s+/gu, '')
  if (!source)
    return null

  let index = 0
  const peek = () => source[index]

  function number(): number | null {
    const match = /^(?:\d+(?:[.,]\d+)*|[.,]\d+)/.exec(source.slice(index))
    if (!match)
      return null
    index += match[0].length
    const token = match[0]
    // With a comma, dots group thousands (pt-BR). Without one, dots followed by groups of exactly
    // three digits are thousands too (`2.500`, `1.000.000`): money never has three decimals.
    if (token.includes(','))
      return token.split(',').length === 2 ? Number(token.replaceAll('.', '').replace(',', '.')) : Number.NaN
    return Number(/^\d{1,3}(?:\.\d{3})+$/.test(token) ? token.replaceAll('.', '') : token)
  }

  function factor(): number | null {
    const char = peek()
    if (char === '-' || char === '+') {
      index++
      const value = factor()
      return value === null ? null : char === '-' ? -value : value
    }
    if (char === '(') {
      index++
      const value = sum()
      if (value === null || peek() !== ')')
        return null
      index++
      return value
    }
    return number()
  }

  function product(): number | null {
    let value = factor()
    while (value !== null && (peek() === '*' || peek() === '/')) {
      const operator = source[index++]
      const right = factor()
      if (right === null)
        return null
      value = operator === '*' ? value * right : value / right
    }
    return value
  }

  function sum(): number | null {
    let value = product()
    while (value !== null && (peek() === '+' || peek() === '-')) {
      const operator = source[index++]
      const right = product()
      if (right === null)
        return null
      value = operator === '+' ? value + right : value - right
    }
    return value
  }

  const result = sum()
  if (result === null || index !== source.length || !Number.isFinite(result))
    return null
  return Math.round(result * 100) / 100
}

/** True when the input is more than a plain number, i.e. worth keeping as an expression. */
export function isExpression(input: string) {
  return /\d\s*[-+*/]|[()]/.test(input.trim().replace(/^[=+-]/, ''))
}
