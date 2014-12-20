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

CREATE TABLE bitcoin_receive_address(
  id SERIAL PRIMARY KEY,
  address TEXT NOT NULL
);

INSERT INTO bitcoin_receive_address(address) VALUES
  ('1K5oPr2BE4QQQ13tXmcfW9eteQCJh6g54u'),
  ('1GA1PqAwmGpj9Wp6r8zLoe5Gdi9hDsb8PS'),
  ('1JP45zuwzKXQu51AxmAKsqRnE68DoPnTPL'),
  ('3MfN5to5K5be2RupWE8rjJHQ6V9L8ypWeh'),
  ('1487tLmthE7ya5dr1Db2JAqPaJnHuDRHA3')
;
