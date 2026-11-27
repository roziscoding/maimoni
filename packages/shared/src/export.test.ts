import { expect, test } from 'bun:test'
import { dataExportSchema } from './export'
import fixture from './export.fixture.json'

// The mobile app's local mode reads and writes this same file (apps/mobile/test/local_export_test.dart).
test('the export fixture matches the schema', () => {
  expect(dataExportSchema.parse(fixture)).toEqual(fixture as never)
})
