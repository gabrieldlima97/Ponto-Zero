-- Ponto Zero: tabelas para avaliações e comentários compartilhados
-- Execute este arquivo no SQL Editor do seu projeto Supabase.

create table if not exists public.avaliacoes (
  id bigint generated always as identity primary key,
  filme_slug text not null,
  nota smallint not null check (nota between 1 and 5),
  criado_em timestamptz not null default now()
);

create table if not exists public.comentarios (
  id bigint generated always as identity primary key,
  filme_slug text not null,
  nome varchar(30) not null default 'Visitante',
  texto varchar(500) not null check (char_length(trim(texto)) between 1 and 500),
  criado_em timestamptz not null default now()
);

create index if not exists avaliacoes_filme_slug_idx
  on public.avaliacoes (filme_slug);

create index if not exists comentarios_filme_slug_criado_em_idx
  on public.comentarios (filme_slug, criado_em desc);

alter table public.avaliacoes enable row level security;
alter table public.comentarios enable row level security;

-- Visitantes podem consultar as avaliações e opiniões publicadas.
create policy "Leitura pública das avaliações"
on public.avaliacoes for select
to anon, authenticated
using (true);

create policy "Visitantes podem avaliar"
on public.avaliacoes for insert
to anon, authenticated
with check (nota between 1 and 5);

create policy "Leitura pública dos comentários"
on public.comentarios for select
to anon, authenticated
using (true);

create policy "Visitantes podem comentar"
on public.comentarios for insert
to anon, authenticated
with check (
  char_length(trim(texto)) between 1 and 500
  and char_length(nome) <= 30
);
