INSERT INTO public.users (
    allow_public_stats_lookup,
    created_at,
    display_name_override,
    slack_uid,
    slack_username,
    timezone,
    updated_at,
    username
)
SELECT
    true,
    CURRENT_TIMESTAMP,
    NULL,
    'TEST123456',
    'testuser',
    'America/New_York',
    CURRENT_TIMESTAMP,
    'testuser'
WHERE NOT EXISTS (
    SELECT 1 FROM public.users WHERE username = 'testuser'
);

INSERT INTO public.email_addresses (created_at, email, source, updated_at, user_id)
SELECT
    CURRENT_TIMESTAMP,
    'test@example.com',
    2,
    CURRENT_TIMESTAMP,
    users.id
FROM public.users
WHERE users.username = 'testuser'
ON CONFLICT (email) DO NOTHING;

INSERT INTO public.api_keys (created_at, name, token, updated_at, user_id)
SELECT
    CURRENT_TIMESTAMP,
    'Development',
    'dev-api-key-12345',
    CURRENT_TIMESTAMP,
    users.id
FROM public.users
WHERE users.username = 'testuser'
ON CONFLICT (token) DO UPDATE SET
    name = EXCLUDED.name,
    updated_at = EXCLUDED.updated_at,
    user_id = EXCLUDED.user_id;
