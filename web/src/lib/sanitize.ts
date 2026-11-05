const MAX = 24
const DISALLOWED = /[^\p{L}\p{N}\s._-]/gu

export function sanitizeNickname(input: string): string {
  return input.replace(DISALLOWED, '').slice(0, MAX)
}

export const NICKNAME_MAX = MAX
