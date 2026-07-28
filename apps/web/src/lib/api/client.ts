import createClient from "openapi-fetch";
import { env } from "$env/dynamic/public";
import type { paths } from "./schema";

export const api = createClient<paths>({
  baseUrl: env.PUBLIC_API_URL || "http://localhost:3002",
});

export function authorized(apiKey: string): HeadersInit {
  return { authorization: `Bearer ${apiKey}` };
}
