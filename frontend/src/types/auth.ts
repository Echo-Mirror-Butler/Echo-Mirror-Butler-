export interface User {
  id: string
  email: string
}

export interface AuthState {
  user: User | null
  isLoading: boolean
}

export interface SignInCredentials {
  email: string
  password: string
}

export interface SignUpCredentials extends SignInCredentials {
  name?: string
}

export interface ResetPasswordCredentials {
  email: string
}

export interface UpdatePasswordCredentials {
  password: string
}
