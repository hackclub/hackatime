# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  error_schema = {
    type: :object,
    properties: {
      error: { type: :string, example: 'Unauthorized' }
    },
    required: [ 'error' ]
  }

  servers = [
    {
      url: 'https://{defaultHost}',
      description: 'Production API',
      variables: {
        defaultHost: {
          default: 'hackatime.hackclub.com'
        }
      }
    },
    {
      url: 'http://{localHost}',
      description: 'Local Development API',
      variables: {
        localHost: {
          default: 'localhost:3000'
        }
      }
    }
  ]

  public_schemas = {
    Error: error_schema,
    User: {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        username: { type: :string, example: 'orpheus' },
        avatar_url: { type: :string, example: 'https://hackatime.hackclub.com/images/athena.png' },
        display_name: { type: :string, example: 'Orpheus' },
        is_admin: { type: :boolean, example: false }
      }
    },
    Heartbeat: {
      type: :object,
      description: 'A single unit of coding activity representing a specific moment in time.',
      properties: {
        id: { type: :integer, example: 1024 },
        entity: { type: :string, nullable: true, example: '/Users/orpheus/hackatime/app/services/chaos_monkey_service.rb', description: 'File path or app name being accessed' },
        type: { type: :string, nullable: true, example: 'file', enum: [ 'file', 'app' ] },
        category: {
          type: :string,
          nullable: true,
          example: 'coding',
          enum: [
            'advising', 'ai coding', 'animating', 'browsing', 'building', 'code reviewing',
            'coding', 'communicating', 'configuring', 'debugging', 'designing', 'indexing',
            'learning', 'manual testing', 'meeting', 'notes', 'planning', 'researching',
            'running tests', 'supporting', 'translating', 'writing docs', 'writing tests'
          ]
        },
        time: { type: :number, format: :float, example: 1709251200.0, description: 'Unix timestamp of the activity' },
        project: { type: :string, nullable: true, example: 'hackatime' },
        branch: { type: :string, nullable: true, example: 'main' },
        language: { type: :string, nullable: true, example: 'Ruby' },
        is_write: { type: :boolean, nullable: true, example: true },
        editor: { type: :string, nullable: true, example: 'VS Code' },
        operating_system: { type: :string, nullable: true, example: 'Mac' },
        machine: { type: :string, nullable: true, example: 'Orpheus-MacBook-Pro' },
        cursorpos: { type: :integer, nullable: true, example: 123 },
        lineno: { type: :integer, nullable: true, example: 42 },
        lines: { type: :integer, nullable: true, example: 100 },
        line_additions: { type: :integer, nullable: true, example: 5 },
        line_deletions: { type: :integer, nullable: true, example: 2 }
      }
    },
    LeaderboardEntry: {
      type: :object,
      properties: {
        rank: { type: :integer, example: 1 },
        user: {
          type: :object,
          properties: {
            id: { type: :integer, example: 42 },
            username: { type: :string, example: 'goat_heidi' },
            avatar_url: { type: :string, example: 'https://...' }
          }
        },
        total_seconds: { type: :number, example: 14500.5, description: 'Total coding duration in seconds for the period' }
      }
    },
    StatsSummary: {
      type: :object,
      properties: {
        total_seconds: { type: :number, example: 3600.0 },
        daily_average: { type: :number, example: 1800.0 },
        languages: {
          type: :array,
          items: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Ruby' },
              total_seconds: { type: :number, example: 2400.0 },
              percent: { type: :number, example: 66.6 }
            }
          }
        },
        projects: {
          type: :array,
          items: {
            type: :object,
            properties: {
              name: { type: :string, example: 'hackatime' },
              total_seconds: { type: :number, example: 3600.0 },
              percent: { type: :number, example: 100.0 }
            }
          }
        },
        editors: {
           type: :array,
           items: {
             type: :object,
             properties: {
               name: { type: :string, example: 'VS Code' },
               total_seconds: { type: :number, example: 3600.0 },
               percent: { type: :number, example: 100.0 }
             }
           }
        },
        streak: { type: :integer, example: 7, description: 'Number of consecutive days the user has coded' }
      }
    },
    WakatimeMirror: {
      type: :object,
      properties: {
        id: { type: :integer, example: 7 },
        target_url: { type: :string, example: 'https://api.wakatime.com/api/v1/users/current/heartbeats' },
        last_sync_at: { type: :string, format: 'date-time', nullable: true },
        status: { type: :string, example: 'active' }
      }
    },
    ProjectRepoMapping: {
      type: :object,
      properties: {
        project_name: { type: :string, example: 'hackatime' },
        repository: {
          type: :object,
          properties: {
            url: { type: :string, example: 'https://github.com/hackclub/hackatime' },
            homepage: { type: :string, example: 'https://hackatime.hackclub.com' }
          }
        },
        is_archived: { type: :boolean, example: false }
      }
    },
    Extension: {
      type: :object,
      properties: {
        id: { type: :string, example: 'vscode' },
        name: { type: :string, example: 'VS Code' },
        download_url: { type: :string, example: 'https://marketplace.visualstudio.com/items?itemName=WakaTime.vscode-wakatime' },
        version: { type: :string, example: '24.0.0' }
      }
    },
    Summary: {
      type: :object,
      properties: {
        user_id: { type: :string, nullable: true, example: 'U123456' },
        from: { type: :string, format: 'date-time', example: '2023-01-01T00:00:00Z' },
        to: { type: :string, format: 'date-time', example: '2023-01-31T23:59:59Z' },
        projects: {
          type: :array,
          items: {
            type: :object,
            properties: {
              key: { type: :string, example: 'hackatime' },
              total: { type: :number, example: 3600.0 }
            }
          }
        },
        languages: {
          type: :array,
          items: {
            type: :object,
            properties: {
              key: { type: :string, example: 'Ruby' },
              total: { type: :number, example: 1200.0 }
            }
          }
        },
        editors: {
          type: :array,
          items: {
            type: :object,
            properties: {
              key: { type: :string, example: 'VS Code' },
              total: { type: :number, example: 3600.0 }
            }
          }
        },
        operating_systems: {
          type: :array,
          items: {
            type: :object,
            properties: {
              key: { type: :string, example: 'Mac' },
              total: { type: :number, example: 3600.0 }
            }
          }
        },
        machines: {
          type: :array,
          items: {
            type: :object,
            properties: {
              key: { type: :string, example: 'MacBook-Pro' },
              total: { type: :number, example: 3600.0 }
            }
          }
        }
      }
    }
  }

  admin_schemas = {
    Error: error_schema,
    AdminApiKey: {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        name: { type: :string, example: 'CI/CD Key' },
        last_used_at: { type: :string, format: 'date-time', nullable: true },
        created_at: { type: :string, format: 'date-time' }
      }
    },
    LeaderboardShadowbanUser: {
      type: :object,
      properties: {
        id: { type: :integer, example: 42 },
        display_name: { type: :string, nullable: true, example: 'Orpheus' },
        avatar_url: { type: :string, nullable: true, example: 'https://...' },
        created_at: { type: :string, format: 'date-time' },
        username: { type: :string, nullable: true, example: 'orpheus' },
        email: { type: :string, nullable: true, example: 'orpheus@example.com' },
        leaderboard_shadowbanned: { type: :boolean, example: true },
        leaderboard_shadowban_reason: { type: :string, nullable: true, example: 'fake leaderboard activity' },
        leaderboard_shadowban_expires_at: { type: :string, format: 'date-time', nullable: true },
        shadowbanned_by: {
          type: :object,
          nullable: true,
          properties: {
            id: { type: :integer, example: 1 },
            display_name: { type: :string, nullable: true, example: 'Admin' },
            username: { type: :string, nullable: true, example: 'admin' },
            avatar_url: { type: :string, nullable: true, example: 'https://...' },
            admin_level: { type: :string, nullable: true, example: 'superadmin' }
          }
        },
        updated_at: { type: :string, format: 'date-time' }
      }
    },
    DeletionRequest: {
      type: :object,
      properties: {
        id: { type: :integer, example: 101 },
        user_id: { type: :integer, example: 42 },
        status: { type: :string, example: 'pending', enum: [ 'pending', 'approved', 'cancelled', 'completed' ] },
        created_at: { type: :string, format: 'date-time' }
      }
    },
    TrustLevelAuditLog: {
      type: :object,
      properties: {
        id: { type: :integer, example: 505 },
        user_id: { type: :integer, example: 42 },
        actor_id: { type: :integer, example: 1 },
        action: { type: :string, example: 'upgraded_to_verified' },
        created_at: { type: :string, format: 'date-time' }
      }
    },
    Permission: {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        role: { type: :string, example: 'admin' },
        resource_type: { type: :string, example: 'User' },
        resource_id: { type: :integer, nullable: true }
      }
    }
  }

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Hackatime API',
        version: 'v1',
        description: <<~DESC
          Hackatime's API gives access to coding activity data.

          We support the WakaTime spec, allowing you to use existing plugins and tools.
        DESC
      },
      paths: {},
      components: {
        securitySchemes: {
          Bearer: {
            type: :http,
            scheme: :bearer,
            description: 'User API Key from settings, prefixed with "Bearer"'
          },
          ApiKeyAuth: {
            type: :apiKey,
            name: 'api_key',
            in: :query,
            description: 'User API Key from settings'
          }
        },
        schemas: public_schemas
      },
      servers: servers
    },
    'admin/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Hackatime Admin API',
        version: 'v1',
        description: <<~DESC
          Admin and internal endpoints for Hackatime.

          Admin endpoints require an Admin API Key or an OAuth access token with the `admin` scope.
          Internal endpoints require an internal environment token. These endpoints are not part of the public API.
        DESC
      },
      paths: {},
      components: {
        securitySchemes: {
          AdminToken: {
            type: :http,
            scheme: :bearer,
            description: 'Admin API Key or OAuth access token with the `admin` scope, prefixed with "Bearer"'
          },
          InternalToken: {
            type: :http,
            scheme: :bearer,
            description: 'Internal API Key from env, prefixed with "Bearer"'
          }
        },
        schemas: admin_schemas
      },
      servers: servers
    }
  }

  config.openapi_format = :yaml
end
