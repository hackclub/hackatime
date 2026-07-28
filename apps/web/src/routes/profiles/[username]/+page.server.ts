import { error } from "@sveltejs/kit";
import type { PageServerLoad } from "./$types";
import { env } from "$env/dynamic/private";

export const load: PageServerLoad = async ({ fetch, params }) => {
  const base = env.API_INTERNAL_URL || "http://localhost:3002";
  const [projectsResponse, statsResponse] = await Promise.all([
    fetch(
      `${base}/api/v1/users/${encodeURIComponent(params.username)}/projects`,
    ),
    fetch(
      `${base}/api/v1/users/${encodeURIComponent(params.username)}/stats?total_seconds=true`,
    ),
  ]);

  if (projectsResponse.status === 404 || statsResponse.status === 404) {
    error(404, "User not found");
  }
  if (!projectsResponse.ok || !statsResponse.ok) {
    error(
      projectsResponse.status || statsResponse.status,
      "Profile is unavailable",
    );
  }

  return {
    username: params.username,
    projects: ((await projectsResponse.json()) as { projects: string[] })
      .projects,
    totalSeconds: ((await statsResponse.json()) as { total_seconds: number })
      .total_seconds,
  };
};
