import {
  assertEquals,
} from 'https://deno.land/std@0.192.0/testing/asserts.ts'
import { extractStorageObjectPaths } from './index.ts'

Deno.test('extractStorageObjectPaths keeps only story-bucket objects', () => {
  const urls = [
    'https://project.supabase.co/storage/v1/object/public/stories/user-123/abc.png',
    'https://project.supabase.co/storage/v1/object/public/stories/user-123/abc.png',
    'https://cdn.example.com/other/path.png',
    'https://project.supabase.co/storage/v1/object/public/other/user-123/other.png',
    'not-a-url',
  ]

  assertEquals(extractStorageObjectPaths(urls), ['user-123/abc.png'])
})

Deno.test('extractStorageObjectPaths returns empty array for non-story data', () => {
  assertEquals(extractStorageObjectPaths([]), [])
  assertEquals(extractStorageObjectPaths(['https://cdn.example.com/x.jpg']), [])
})
