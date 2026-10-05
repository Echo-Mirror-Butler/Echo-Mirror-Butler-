import {
  assertEquals,
  assert,
  assertStringIncludes,
} from 'https://deno.land/std@0.192.0/testing/asserts.ts'
import {
  assertCronSecretConfigured,
  authorizeCronRequest,
  CRON_SECRET_ENV,
  CronSecretMissingError,
  cronDenialResponse,
  extractPresentedCronSecret,
  resolveCronSecret,
  secretsMatch,
} from './require-cron-secret.ts'

const envWith = (vars: Record<string, string>) => ({
  get: (key: string) => vars[key],
})

const SECRET = 's3cret-cron-value'

const post = (headers: Record<string, string> = {}) =>
  new Request('http://localhost/cleanup', { method: 'POST', headers })

Deno.test('resolveCronSecret reads CRON_SECRET and never falls back', () => {
  assertEquals(resolveCronSecret(envWith({ [CRON_SECRET_ENV]: `  ${SECRET}  ` })), SECRET)

  for (const missing of [{}, { CRON_SECRET: '' }, { CRON_SECRET: '   ' }]) {
    let threw = false
    try {
      resolveCronSecret(envWith(missing as Record<string, string>))
    } catch (error) {
      threw = error instanceof CronSecretMissingError
    }
    assert(threw, `expected CronSecretMissingError for ${JSON.stringify(missing)}`)
  }
})

Deno.test('assertCronSecretConfigured reports a missing secret instead of throwing', () => {
  const messages: string[] = []
  assertEquals(assertCronSecretConfigured((m) => messages.push(m), envWith({})), false)
  assertEquals(messages.length, 1)
  assertStringIncludes(messages[0], CRON_SECRET_ENV)

  assertEquals(
    assertCronSecretConfigured(() => {}, envWith({ [CRON_SECRET_ENV]: SECRET })),
    true,
  )
})

Deno.test('extractPresentedCronSecret accepts the header and the bearer scheme', () => {
  assertEquals(extractPresentedCronSecret(post({ 'x-cron-secret': SECRET })), SECRET)
  assertEquals(extractPresentedCronSecret(post({ authorization: `Bearer ${SECRET}` })), SECRET)
  assertEquals(extractPresentedCronSecret(post({ authorization: `bearer ${SECRET}` })), SECRET)

  // Nothing usable presented: absent, empty, or a scheme without a token.
  assertEquals(extractPresentedCronSecret(post()), null)
  assertEquals(extractPresentedCronSecret(post({ 'x-cron-secret': '   ' })), null)
  assertEquals(extractPresentedCronSecret(post({ authorization: 'Bearer' })), null)
  assertEquals(extractPresentedCronSecret(post({ authorization: 'Basic abc' })), null)
})

Deno.test('secretsMatch is exact and length-safe', () => {
  assert(secretsMatch(SECRET, SECRET))
  assertEquals(secretsMatch(`${SECRET}x`, SECRET), false)
  assertEquals(secretsMatch(SECRET.slice(0, -1), SECRET), false)
  assertEquals(secretsMatch('', SECRET), false)
  assertEquals(secretsMatch('', ''), true)
})

Deno.test('authorizeCronRequest denies callers without the credential', () => {
  const env = envWith({ [CRON_SECRET_ENV]: SECRET })

  const anonymous = authorizeCronRequest(post(), env)
  assertEquals(anonymous.ok, false)
  assertEquals((anonymous as { status: number }).status, 401)

  const wrong = authorizeCronRequest(post({ 'x-cron-secret': 'not-the-secret' }), env)
  assertEquals(wrong.ok, false)
  assertEquals((wrong as { status: number }).status, 401)
})

Deno.test('authorizeCronRequest fails closed when the deployment has no secret', () => {
  // A valid-looking credential with no configured secret must not be accepted:
  // "no secret" has to mean "nobody gets in", not "everybody does".
  const result = authorizeCronRequest(
    post({ authorization: `Bearer ${SECRET}` }),
    envWith({}),
  )

  assertEquals(result.ok, false)
  assertEquals((result as { status: number }).status, 500)
  assertStringIncludes((result as { message: string }).message, CRON_SECRET_ENV)
})

Deno.test('authorizeCronRequest accepts the scheduler credential both ways', () => {
  const env = envWith({ [CRON_SECRET_ENV]: SECRET })

  assertEquals(authorizeCronRequest(post({ authorization: `Bearer ${SECRET}` }), env).ok, true)
  assertEquals(authorizeCronRequest(post({ 'x-cron-secret': SECRET }), env).ok, true)
})

Deno.test('cronDenialResponse returns a Response only when denied', async () => {
  const env = envWith({ [CRON_SECRET_ENV]: SECRET })

  const denial = cronDenialResponse(post(), env)
  assert(denial instanceof Response)
  assertEquals(denial!.status, 401)
  assertStringIncludes(await denial!.text(), 'Missing scheduler credential')

  assertEquals(cronDenialResponse(post({ 'x-cron-secret': SECRET }), env), null)
})
