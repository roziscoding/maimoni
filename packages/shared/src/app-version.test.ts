import { describe, expect, test } from 'bun:test'
import { appVersion, appVersionFromTag, isPrereleaseCode } from './app-version'

describe('appVersion', () => {
  test('maps a stable version to the same name on both platforms', () => {
    expect(appVersion('1.3.0')).toEqual({ version: '1.3.0', iosVersion: '1.3.0', code: 1030099 })
  })

  test('drops the prerelease from the iOS version and numbers it in the build', () => {
    expect(appVersion('1.3.0-beta.2')).toEqual({ version: '1.3.0-beta.2', iosVersion: '1.3.0', code: 1030002 })
  })

  test('orders prereleases below their stable release and above the previous one', () => {
    const codes = ['1.2.9', '1.3.0-beta.1', '1.3.0-beta.2', '1.3.0', '1.3.1'].map(version => appVersion(version).code)
    expect(codes).toEqual([...codes].sort((a, b) => a - b))
  })

  test('rejects versions the build number cannot hold', () => {
    expect(() => appVersion('1.100.0')).toThrow()
    expect(() => appVersion('1.0.0-beta.99')).toThrow()
    expect(() => appVersion('1.0')).toThrow()
  })
})

describe('appVersionFromTag', () => {
  test('reads mobile release tags and ignores the rest', () => {
    expect(appVersionFromTag('mobile-v2.0.0-beta.1')?.code).toBe(2000001)
    expect(appVersionFromTag('web-v2.0.0')).toBeNull()
    expect(appVersionFromTag('mobile-vnext')).toBeNull()
  })
})

test('isPrereleaseCode tells betas from stable builds', () => {
  expect(isPrereleaseCode(1030002)).toBe(true)
  expect(isPrereleaseCode(1030099)).toBe(false)
})
