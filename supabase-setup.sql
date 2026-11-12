-- Ponto Zero — estrutura completa do Supabase
-- Seguro para executar novamente: tabelas e índices usam IF NOT EXISTS.
-- O cliente público usa somente a chave publishable; nunca coloque service_role no site.

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

create table if not exists public.perfis (
  user_id uuid primary key references auth.users(id) on delete cascade,
  apelido text not null default 'Cinéfilo'
    check (char_length(apelido) between 1 and 30),
  generos text[] not null default '{}',
  atualizado_em timestamptz not null default now()
);

create table if not exists public.listas_filmes (
  user_id uuid not null references auth.users(id) on delete cascade,
  filme_slug text not null,
  criado_em timestamptz not null default now(),
  primary key (user_id, filme_slug)
);

-- Cada usuário pode votar uma vez em cada filme.
create table if not exists public.votos_batalha (
  user_id uuid not null references auth.users(id) on delete cascade,
  filme_slug text not null,
  criado_em timestamptz not null default now(),
  primary key (user_id, filme_slug)
);

create table if not exists public.pontuacoes_quiz (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  apelido text not null check (char_length(apelido) between 1 and 30),
  pontos integer not null check (pontos between 0 and 10000),
  criado_em timestamptz not null default now()
);

create index if not exists avaliacoes_filme_slug_idx
  on public.avaliacoes (filme_slug);
create index if not exists comentarios_filme_slug_criado_em_idx
  on public.comentarios (filme_slug, criado_em desc);
create index if not exists listas_filmes_user_criado_idx
  on public.listas_filmes (user_id, criado_em desc);
create index if not exists votos_batalha_filme_idx
  on public.votos_batalha (filme_slug);
create index if not exists pontuacoes_quiz_user_idx
  on public.pontuacoes_quiz (user_id);
create index if not exists pontuacoes_quiz_pontos_idx
  on public.pontuacoes_quiz (pontos desc);

alter table public.avaliacoes enable row level security;
alter table public.comentarios enable row level security;
alter table public.perfis enable row level security;
alter table public.listas_filmes enable row level security;
alter table public.votos_batalha enable row level security;
alter table public.pontuacoes_quiz enable row level security;

-- Remover políticas antigas para manter o script idempotente e sem permissões duplicadas.
drop policy if exists "Leitura pública das avaliações" on public.avaliacoes;
drop policy if exists "Visitantes podem avaliar" on public.avaliacoes;
drop policy if exists "Leitura pública dos comentários" on public.comentarios;
drop policy if exists "Visitantes podem comentar" on public.comentarios;
drop policy if exists "Perfil: leitura do próprio" on public.perfis;
drop policy if exists "Perfil: inserir próprio" on public.perfis;
drop policy if exists "Perfil: atualizar próprio" on public.perfis;
drop policy if exists "Usuário cria seu perfil" on public.perfis;
drop policy if exists "Usuário altera seu perfil" on public.perfis;
drop policy if exists "Perfis públicos para leitura" on public.perfis;
drop policy if exists "Lista: leitura própria" on public.listas_filmes;
drop policy if exists "Lista: adicionar próprio" on public.listas_filmes;
drop policy if exists "Lista: remover próprio" on public.listas_filmes;
drop policy if exists "Votos: placar público" on public.votos_batalha;
drop policy if exists "Votos: inserir próprio" on public.votos_batalha;
drop policy if exists "Votos da comunidade visíveis" on public.votos_batalha;
drop policy if exists "Usuário vota uma vez por filme" on public.votos_batalha;
drop policy if exists "Quiz: placar público" on public.pontuacoes_quiz;
drop policy if exists "Quiz: inserir própria pontuação" on public.pontuacoes_quiz;
drop policy if exists "Placar do quiz público" on public.pontuacoes_quiz;
drop policy if exists "Usuário registra própria pontuação" on public.pontuacoes_quiz;

create policy "Leitura pública das avaliações"
  on public.avaliacoes for select to anon, authenticated using (true);
create policy "Visitantes podem avaliar"
  on public.avaliacoes for insert to anon, authenticated
  with check (nota between 1 and 5);

create policy "Leitura pública dos comentários"
  on public.comentarios for select to anon, authenticated using (true);
create policy "Visitantes podem comentar"
  on public.comentarios for insert to anon, authenticated
  with check (
    char_length(trim(texto)) between 1 and 500
    and char_length(nome) <= 30
  );

-- Perfil e lista são privados: cada conta só acessa seus próprios registros.
create policy "Perfil: leitura do próprio"
  on public.perfis for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Perfil: inserir próprio"
  on public.perfis for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Perfil: atualizar próprio"
  on public.perfis for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Lista: leitura própria"
  on public.listas_filmes for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Lista: adicionar próprio"
  on public.listas_filmes for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Lista: remover próprio"
  on public.listas_filmes for delete to authenticated
  using ((select auth.uid()) = user_id);

-- O placar é público; inserir exige autenticação e o próprio user_id.
create policy "Votos: placar público"
  on public.votos_batalha for select to anon, authenticated using (true);
create policy "Votos: inserir próprio"
  on public.votos_batalha for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Quiz: placar público"
  on public.pontuacoes_quiz for select to anon, authenticated using (true);
create policy "Quiz: inserir própria pontuação"
  on public.pontuacoes_quiz for insert to authenticated
  with check ((select auth.uid()) = user_id);

grant select on public.avaliacoes, public.comentarios to anon, authenticated;
grant insert on public.avaliacoes, public.comentarios to anon, authenticated;
grant select, insert, update on public.perfis to authenticated;
grant select, insert, delete on public.listas_filmes to authenticated;
grant select on public.votos_batalha, public.pontuacoes_quiz to anon, authenticated;
grant insert on public.votos_batalha, public.pontuacoes_quiz to authenticated;

-- Rankings calculados no banco: evita baixar milhares de linhas para o navegador.
create or replace view public.ranking_filmes with (security_invoker = true) as
select filme_slug, round(avg(nota)::numeric, 2) as media, count(*)::bigint as quantidade
from public.avaliacoes
group by filme_slug;

create or replace view public.ranking_quiz with (security_invoker = true) as
select user_id, max(apelido) as apelido, sum(pontos)::bigint as pontos,
       count(*)::bigint as respostas
from public.pontuacoes_quiz
group by user_id;

create or replace view public.ranking_batalha with (security_invoker = true) as
select filme_slug, count(*)::bigint as votos
from public.votos_batalha
group by filme_slug;

grant select on public.ranking_filmes, public.ranking_quiz, public.ranking_batalha to anon, authenticated;
