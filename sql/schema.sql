-- schema.sql — DuckDB (padrão inicial). Executado por R/db.R via DBI::dbExecute.
-- Convenção: dados brutos nunca são alterados; toda transformação gera nova tabela/versão.
-- Chaves: seq_documento (decisão publicada) < numero_registro (processo no STJ) ; evento decisório = (seq_documento, k).

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS ann;
CREATE SCHEMA IF NOT EXISTS res;

-- 1. Inventário de arquivos brutos (imutáveis) -------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.files (
  file_name        VARCHAR PRIMARY KEY,
  dataset          VARCHAR NOT NULL,          -- ex.: integras, precedentes, tramitando, ipca
  key_date         VARCHAR,                   -- AAAAMMDD ou AAAAMM
  url              VARCHAR,
  size_bytes       BIGINT,
  sha256           VARCHAR,
  downloaded_at    TIMESTAMP,
  ckan_last_modified TIMESTAMP
);

-- 2. Documentos (decisão ou acórdão publicado) -------------------------------------------------
CREATE TABLE IF NOT EXISTS stg.documents (
  seq_documento     BIGINT PRIMARY KEY,
  numero_registro   VARCHAR,                  -- processo no STJ (chave de ligação com acervo em tramitação)
  processo          VARCHAR,                  -- "AREsp 1703858"
  classe            VARCHAR,                  -- sigla da classe (AREsp, REsp, EREsp, ...)
  numero_na_classe  BIGINT,
  tipo_documento    VARCHAR,                  -- DECISAO | ACORDAO (normalizado sem acento)
  recurso_interno   VARCHAR,                  -- AgInt, AgRg, EDcl, ... ou NULL (processo principal)
  teor              VARCHAR,                  -- Não Conhecendo | Negando | Concedendo | Outros ...
  descricao_monocratica VARCHAR,
  ministro          VARCHAR,
  data_publicacao   DATE,
  data_recebimento  DATE,
  data_distribuicao DATE,
  assuntos_raw      VARCHAR,
  assuntos_formato  VARCHAR,                  -- caminho_pontuado | leaf_lista (deriva de esquema 2023)
  n_chars           INTEGER,
  text_sha256       VARCHAR,
  source_zip        VARCHAR,
  source_meta       VARCHAR
);

-- texto integral separado (grande) --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stg.document_text (
  seq_documento BIGINT PRIMARY KEY,
  text_norm     VARCHAR                       -- após normalize_text()
);

-- assuntos CNJ (um por linha, folha + caminho) --------------------------------------------------
CREATE TABLE IF NOT EXISTS stg.document_subjects (
  seq_documento BIGINT,
  ordem         INTEGER,
  codigo_leaf   INTEGER,
  caminho       VARCHAR,                      -- "01156.06220.07779." quando disponível
  PRIMARY KEY (seq_documento, ordem)
);
CREATE TABLE IF NOT EXISTS raw.cnj_assuntos (
  codigo INTEGER PRIMARY KEY, descricao VARCHAR, cod_pai INTEGER, nivel INTEGER, situacao VARCHAR
);

-- 3. Processo (uma linha por numero_registro; enriquecido por acervo em tramitação / texto) ------
CREATE TABLE IF NOT EXISTS stg.cases (
  numero_registro   VARCHAR PRIMARY KEY,
  numero_unico_cnj  VARCHAR,
  origem_tribunal   VARCHAR,
  origem_uf         VARCHAR,
  origem_fonte      VARCHAR,                  -- tramitando | texto_inicio | texto_geral | numero_cnj
  orgao_julgador    VARCHAR,                  -- T3, T4, S2 ...
  classe            VARCHAR,
  assunto_principal INTEGER,
  data_recebimento_stj DATE,
  snapshot_date     DATE
);

-- 4. Expressões monetárias extraídas (candidatos) ---------------------------------------------
CREATE TABLE IF NOT EXISTS stg.money_candidates (
  candidate_id      BIGINT PRIMARY KEY,
  seq_documento     BIGINT NOT NULL,
  start_pos         INTEGER, end_pos INTEGER, rel_pos DOUBLE,
  raw               VARCHAR,
  value             DOUBLE,
  unit              VARCHAR,                  -- BRL | SM (salário mínimo)
  form              VARCHAR,                  -- cifra | escala | extenso | salario_minimo
  extenso_parenthetical BOOLEAN, extenso_mismatch BOOLEAN,
  category          VARCHAR,                  -- dano_moral | dano_material | honorarios | multa | custas | valor_causa | contrato_divida | ...
  cat_dist          DOUBLE,
  stage             VARCHAR,                  -- pedido | origem_sentenca | origem_acordao | stj | indeterminado
  stage_dist        DOUBLE,
  direction         VARCHAR,                  -- aumento | reducao | manutencao | indeterminado
  in_precedent_quote BOOLEAN, in_origin_ementa BOOLEAN, per_capita BOOLEAN, reference_value BOOLEAN,
  ctx_before        VARCHAR, ctx_after VARCHAR,
  extractor_version VARCHAR
);

-- 5. Eventos decisórios consolidados (após regras de consistência + revisão) -------------------
CREATE TABLE IF NOT EXISTS stg.award_events (
  seq_documento        BIGINT,
  event_k              INTEGER,               -- 1..n por documento (vários autores/pedidos)
  tipo_dano            VARCHAR,               -- moral | estetico | coletivo
  n_vitimas            INTEGER,
  valor_pedido         DOUBLE,
  valor_sentenca       DOUBLE,
  valor_acordao_origem DOUBLE,
  valor_stj            DOUBLE,
  resultado_stj        VARCHAR,               -- mantido_sumula7 | mantido | reduzido_stj | majorado_stj | provido_verificar | ...
  ambiguo              BOOLEAN,
  fonte_valores        VARCHAR,               -- automatico | revisado
  revisor              VARCHAR, revisado_em TIMESTAMP,
  PRIMARY KEY (seq_documento, event_k)
);

-- 6. Categorias jurídicas (matéria) por documento -----------------------------------------------
CREATE TABLE IF NOT EXISTS stg.document_topics (
  seq_documento BIGINT, materia VARCHAR, metodo VARCHAR, score DOUBLE, PRIMARY KEY (seq_documento, materia, metodo)
);

-- 7. Anotação manual ---------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ann.money_annotations (
  candidate_id BIGINT, annotator VARCHAR, annotated_at TIMESTAMP,
  true_category VARCHAR, true_stage VARCHAR, true_direction VARCHAR, true_in_precedent BOOLEAN, note VARCHAR,
  PRIMARY KEY (candidate_id, annotator)
);
CREATE TABLE IF NOT EXISTS ann.document_annotations (
  seq_documento BIGINT, annotator VARCHAR, annotated_at TIMESTAMP,
  materia VARCHAR, n_vitimas INTEGER, valor_sentenca DOUBLE, valor_acordao_origem DOUBLE, valor_stj DOUBLE,
  resultado_stj VARCHAR, incluir BOOLEAN, motivo_exclusao VARCHAR, note VARCHAR,
  PRIMARY KEY (seq_documento, annotator)
);

-- 8. Referências externas -------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.ipca (ref_month VARCHAR PRIMARY KEY, ipca_index DOUBLE);
CREATE TABLE IF NOT EXISTS raw.precedentes_temas (
  sequencial_precedente INTEGER PRIMARY KEY, tipo VARCHAR, numero INTEGER, data_afetacao DATE, data_julgamento DATE,
  data_publicacao DATE, situacao VARCHAR, orgao_julgador VARCHAR, questao VARCHAR, tese VARCHAR
);

-- 9. Resultados de modelos (metadados, não os objetos) ------------------------------------------------
CREATE TABLE IF NOT EXISTS res.model_runs (
  run_id VARCHAR PRIMARY KEY, model VARCHAR, spec VARCHAR, sample_def VARCHAR, n INTEGER, started_at TIMESTAMP,
  git_commit VARCHAR, seed INTEGER, metrics_json VARCHAR
);
