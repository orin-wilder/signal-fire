import { api, setToken, clearToken } from "./api";

export interface CurrentUser {
  id: number;
  email: string | null;
  name: string | null;
  auth_method: string;
  is_host: boolean;
  is_admin: boolean;
  push_token: string | null;
  notification_prefs: Record<string, boolean>;
  host_sso_url?: string;
}

interface AuthResponse {
  token: string;
  user: CurrentUser;
}

export async function signUp(email: string, password: string): Promise<AuthResponse> {
  const res = await api.post<AuthResponse>(
    "/api/v1/auth/sign_up",
    { email, password },
    false
  );
  await setToken(res.token);
  return res;
}

export async function signIn(email: string, password: string): Promise<AuthResponse> {
  const res = await api.post<AuthResponse>(
    "/api/v1/auth/sign_in",
    { email, password },
    false
  );
  await setToken(res.token);
  return res;
}

export async function signInWithGoogle(idToken: string): Promise<AuthResponse> {
  const res = await api.post<AuthResponse>(
    "/api/v1/auth/google",
    { id_token: idToken },
    false
  );
  await setToken(res.token);
  return res;
}

export async function signOut(): Promise<void> {
  await api.delete("/api/v1/auth/sign_out").catch(() => {});
  await clearToken();
}
