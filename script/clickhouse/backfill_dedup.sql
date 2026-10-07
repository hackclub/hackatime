-- Copies one user-shard of heartbeats from the staging copy (a byte-exact copy of
-- Postgres) into the production schema, dropping exact duplicates.
--
-- Two rows are exact duplicates when every heartbeat field matches (all columns
-- except id, created_at, updated_at, deleted_at and the dropped fields_hash /
-- version / ysws_program). Postgres's fields_hash should have prevented them, but
-- changes to import normalisation let ~23M through.
--
-- Survivor per duplicate group: a live row beats a soft-deleted one, then the
-- lowest id (the original). Params: {src_db,src,dst_db,dst:Identifier},
-- {shard:UInt8}, {shards:UInt8}.
INSERT INTO {dst_db:Identifier}.{dst:Identifier}
SELECT * EXCEPT (dup_rank)
FROM
(
    SELECT
        id, user_id, time, project, branch, entity, category, editor, language, machine, operating_system, type,
        user_agent, ip_address, dependencies, dependencies_is_null, dependencies_json,
        lineno, lines, cursorpos, line_additions, line_deletions, project_root_count, is_write,
        source_type, ja4_id, ai_model, ai_session, ai_subscription_plan, ai_input_tokens, ai_output_tokens,
        ai_prompt_length, ai_line_changes, human_line_changes, deleted_at, created_at, updated_at,
        row_number() OVER (
            PARTITION BY user_id, time, entity, type, project, branch, language, editor, category, machine,
                         operating_system, user_agent, lineno, lines, cursorpos, line_additions, line_deletions,
                         project_root_count, is_write, dependencies, dependencies_is_null, dependencies_json,
                         ai_model, ai_session, ai_subscription_plan, ai_input_tokens, ai_output_tokens,
                         ai_prompt_length, ai_line_changes, human_line_changes, source_type, ip_address, ja4_id
            ORDER BY deleted_at IS NOT NULL, id
        ) AS dup_rank
    FROM {src_db:Identifier}.{src:Identifier}
    WHERE user_id % {shards:UInt8} = {shard:UInt8}
)
WHERE dup_rank = 1
SETTINGS max_threads = 8, max_memory_usage = 20000000000, max_bytes_before_external_sort = 8000000000,
         max_insert_threads = 4, max_partitions_per_insert_block = 0
