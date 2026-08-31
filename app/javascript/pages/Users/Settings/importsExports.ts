export type HeartbeatImportStatus = {
  state: string;
  source_kind: string;
  imported_count: number | null;
  skipped_count: number | null;
  error_message?: string | null;
  cooldown_until?: string | null;
  source_filename?: string | null;
};

export type DataExport = {
  total_heartbeats: string;
  total_coding_time: string;
  heartbeats_last_7_days: string;
  is_restricted: boolean;
};
