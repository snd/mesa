CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE "user"(
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL
);

INSERT INTO "user"(name) VALUES
  ('laura'),
  ('dale'),
  ('audrey'),
  ('leland'),
  ('donna'),
  ('ben')
;

CREATE TABLE event(
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES "user"(id),
  created_at timestamptz NOT NULL,
  data JSON
);
