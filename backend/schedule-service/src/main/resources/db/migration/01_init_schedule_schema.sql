
CREATE TABLE users (
    id uuid PRIMARY KEY,
    firstname VARCHAR(64) NOT NULL,
    surname VARCHAR(64) NOT NULL,
    email VARCHAR(128) NOT NULL UNIQUE,
    timezone VARCHAR(64) DEFAULT 'UTC',
    telegram_id VARCHAR(64),
    creation_time TIMESTAMP DEFAULT NOW()
);

CREATE TABLE teams (
    id uuid PRIMARY KEY,
    team_name VARCHAR(64) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE team_members (
    team_id uuid REFERENCES teams(id),
    user_id uuid REFERENCES  users(id),
    member_role VARCHAR(32) NOT NULL DEFAULT 'MEMBER', -- 'MEMBER', 'LEAD'
    PRIMARY KEY (team_id, user_id)
);

CREATE TABLE escalation_policies (
    id uuid PRIMARY KEY,
    policy_name varchar(32),
    escalation_name varchar(128) NOT NULL,
    repeat_count INTEGER DEFAULT 3
);

CREATE TABLE escalation_steps (
    id uuid PRIMARY KEY,
    policy_id uuid REFERENCES escalation_policies(id),
    delay_seconds INTEGER DEFAULT 180,
    target_type VARCHAR(32),
    target_id uuid NOT NULL,
    current_step INTEGER
);

CREATE TABLE schedules (
    id uuid PRIMARY KEY,
    team_id uuid REFERENCES teams(id),
    name VARCHAR(64) NOT NULL,
    timezone VARCHAR(64) NOT NULL DEFAULT 'UTC'
);

CREATE TABLE rotation_configs (
    id uuid PRIMARY KEY,
    schedule_id uuid REFERENCES schedules(id) ON DELETE CASCADE,
    name VARCHAR(64),
    type VARCHAR(32) NOT NULL,
    start_date TIMESTAMP NOT NULL,
    shift_length_hours INTEGER NOT NULL,
    participants_order uuid[] NOT NULL
);

CREATE TABLE schedule_shifts (
    id uuid PRIMARY KEY,
    schedule_id uuid REFERENCES schedules(id) ON DELETE CASCADE,
    user_id uuid REFERENCES users(id),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL
);
