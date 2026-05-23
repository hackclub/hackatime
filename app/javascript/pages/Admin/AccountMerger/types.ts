export type UserResult = {
  id: number;
  display_name: string;
  avatar_url: string | null;
  created_at: string | null;
  username: string;
  email: string | null;
};

export type Side = "older" | "newer";
