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

 
-- Recursos sociais Ponto Zero: notas individuais, amizades e chat privado.
create table if not exists public.avaliacoes_usuarios (
  user_id uuid not null references auth.users(id) on delete cascade,
  filme_slug text not null,
  nota smallint not null check (nota between 0 and 10),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  primary key (user_id, filme_slug)
);
create index if not exists avaliacoes_usuarios_filme_idx on public.avaliacoes_usuarios (filme_slug, nota desc);
create index if not exists avaliacoes_usuarios_user_idx on public.avaliacoes_usuarios (user_id, atualizado_em desc);

create table if not exists public.solicitacoes_amizade (
  id bigint generated always as identity primary key,
  remetente_id uuid not null references auth.users(id) on delete cascade,
  destinatario_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pendente' check (status in ('pendente','aceita','recusada')),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint solicitacao_nao_para_si check (remetente_id <> destinatario_id),
  constraint solicitacao_unica unique (remetente_id, destinatario_id)
);
create index if not exists solicitacoes_destinatario_status_idx on public.solicitacoes_amizade (destinatario_id, status, criado_em desc);
create index if not exists solicitacoes_remetente_status_idx on public.solicitacoes_amizade (remetente_id, status, criado_em desc);
create unique index if not exists solicitacoes_amizade_par_unico_idx on public.solicitacoes_amizade (least(remetente_id, destinatario_id), greatest(remetente_id, destinatario_id));

create table if not exists public.mensagens (
  id bigint generated always as identity primary key,
  remetente_id uuid not null references auth.users(id) on delete cascade,
  destinatario_id uuid not null references auth.users(id) on delete cascade,
  texto varchar(2000) not null check (char_length(trim(texto)) between 1 and 2000),
  criado_em timestamptz not null default now(),
  constraint mensagem_nao_para_si check (remetente_id <> destinatario_id)
);
create index if not exists mensagens_conversa_idx on public.mensagens (remetente_id, destinatario_id, criado_em desc);
create index if not exists mensagens_destinatario_idx on public.mensagens (destinatario_id, criado_em desc);

alter table public.avaliacoes_usuarios enable row level security;
alter table public.solicitacoes_amizade enable row level security;
alter table public.mensagens enable row level security;

drop policy if exists "Perfil: leitura do próprio" on public.perfis;
drop policy if exists "Perfis públicos para leitura" on public.perfis;
create policy "Perfis públicos para leitura" on public.perfis for select to anon, authenticated using (true);

drop policy if exists "Notas pessoais: leitura pública" on public.avaliacoes_usuarios;
drop policy if exists "Notas pessoais: inserir própria" on public.avaliacoes_usuarios;
drop policy if exists "Notas pessoais: atualizar própria" on public.avaliacoes_usuarios;
create policy "Notas pessoais: leitura pública" on public.avaliacoes_usuarios for select to anon, authenticated using (true);
create policy "Notas pessoais: inserir própria" on public.avaliacoes_usuarios for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Notas pessoais: atualizar própria" on public.avaliacoes_usuarios for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "Amizades: ver próprias solicitações" on public.solicitacoes_amizade;
drop policy if exists "Amizades: enviar convite próprio" on public.solicitacoes_amizade;
drop policy if exists "Amizades: destinatário responde" on public.solicitacoes_amizade;
drop policy if exists "Amizades: participantes podem cancelar" on public.solicitacoes_amizade;
create policy "Amizades: ver próprias solicitações" on public.solicitacoes_amizade for select to authenticated using ((select auth.uid()) in (remetente_id, destinatario_id));
create policy "Amizades: enviar convite próprio" on public.solicitacoes_amizade for insert to authenticated with check ((select auth.uid()) = remetente_id and remetente_id <> destinatario_id and status = 'pendente');
create policy "Amizades: destinatário responde" on public.solicitacoes_amizade for update to authenticated using ((select auth.uid()) = destinatario_id and status = 'pendente') with check ((select auth.uid()) = destinatario_id and status in ('aceita','recusada'));
create policy "Amizades: participantes podem cancelar" on public.solicitacoes_amizade for delete to authenticated using ((select auth.uid()) in (remetente_id, destinatario_id));

drop policy if exists "Mensagens: participantes leem conversa" on public.mensagens;
drop policy if exists "Mensagens: enviar para amigo" on public.mensagens;
create policy "Mensagens: participantes leem conversa" on public.mensagens for select to authenticated using (
  (select auth.uid()) in (remetente_id, destinatario_id) and exists (
    select 1 from public.solicitacoes_amizade a where a.status='aceita' and
    ((a.remetente_id=mensagens.remetente_id and a.destinatario_id=mensagens.destinatario_id) or
     (a.remetente_id=mensagens.destinatario_id and a.destinatario_id=mensagens.remetente_id))
  )
);
create policy "Mensagens: enviar para amigo" on public.mensagens for insert to authenticated with check (
  (select auth.uid())=remetente_id and remetente_id<>destinatario_id and char_length(trim(texto)) between 1 and 2000 and exists (
    select 1 from public.solicitacoes_amizade a where a.status='aceita' and
    ((a.remetente_id=mensagens.remetente_id and a.destinatario_id=mensagens.destinatario_id) or
     (a.remetente_id=mensagens.destinatario_id and a.destinatario_id=mensagens.remetente_id))
  )
);

grant select on public.perfis, public.avaliacoes_usuarios to anon, authenticated;
grant insert, update on public.avaliacoes_usuarios to authenticated;
grant select, insert, update(status), delete on public.solicitacoes_amizade to authenticated;
grant select, insert on public.mensagens to authenticated;
create or replace view public.ranking_notas_usuarios with (security_invoker = true) as
select filme_slug, round(avg(nota)::numeric,2) as media, count(*)::bigint as quantidade from public.avaliacoes_usuarios group by filme_slug;
grant select on public.ranking_notas_usuarios to anon, authenticated;
do $$ begin alter publication supabase_realtime add table public.mensagens; exception when duplicate_object then null; when undefined_object then null; end $$;

grant usage, select on sequence public.solicitacoes_amizade_id_seq, public.mensagens_id_seq to authenticated;


-- ============================================================
-- HARDENING ADD-ON (production roles, moderation and quiz RPC)
-- Also applied to the live Supabase project.
-- ============================================================
create schema if not exists private;

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','moderator')),
  created_at timestamptz not null default now()
);
alter table public.user_roles enable row level security;
revoke all on public.user_roles from anon, authenticated;
grant select on public.user_roles to authenticated;
drop policy if exists "Users can read their own role" on public.user_roles;
create policy "Users can read their own role" on public.user_roles
  for select to authenticated using ((select auth.uid()) = user_id);

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.user_roles r where r.user_id=(select auth.uid()) and r.role='admin'); $$;
revoke all on function private.is_admin() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;

-- After the owner account exists, assign the owner role manually in the SQL editor:
-- insert into public.user_roles(user_id,role)
-- select id,'admin' from auth.users where lower(email)=lower('<owner-email>')
-- on conflict(user_id) do update set role='admin';
-- Never expose a service-role key or allow users to edit this table.

alter table public.avaliacoes add column if not exists user_id uuid references auth.users(id) on delete cascade;
alter table public.avaliacoes alter column user_id set not null;
create unique index if not exists avaliacoes_user_filme_unique on public.avaliacoes(user_id,filme_slug);
drop policy if exists "Visitantes podem avaliar" on public.avaliacoes;
drop policy if exists "Ratings: insert own" on public.avaliacoes;
drop policy if exists "Ratings: update own" on public.avaliacoes;
drop policy if exists "Ratings: delete own" on public.avaliacoes;
drop policy if exists "Admins can delete ratings" on public.avaliacoes;
create policy "Ratings: insert own" on public.avaliacoes for insert to authenticated with check ((select auth.uid())=user_id);
create policy "Ratings: update own" on public.avaliacoes for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy "Ratings: delete own" on public.avaliacoes for delete to authenticated using ((select auth.uid())=user_id);
create policy "Admins can delete ratings" on public.avaliacoes for delete to authenticated using ((select private.is_admin()));
revoke insert,update,delete on public.avaliacoes from anon;
grant select on public.avaliacoes to anon,authenticated;
grant insert,update,delete on public.avaliacoes to authenticated;

alter table public.comentarios add column if not exists user_id uuid references auth.users(id) on delete set null;
drop policy if exists "Visitantes podem comentar" on public.comentarios;
drop policy if exists "Comments: insert authenticated" on public.comentarios;
drop policy if exists "Comments: delete own" on public.comentarios;
drop policy if exists "Admins can delete comments" on public.comentarios;
create policy "Comments: insert authenticated" on public.comentarios for insert to authenticated with check ((select auth.uid())=user_id);
create policy "Comments: delete own" on public.comentarios for delete to authenticated using ((select auth.uid())=user_id);
create policy "Admins can delete comments" on public.comentarios for delete to authenticated using ((select private.is_admin()));
revoke insert,update,delete on public.comentarios from anon;
grant select on public.comentarios to anon,authenticated;
grant insert,delete on public.comentarios to authenticated;

create or replace function private.enforce_comment_rate_limit()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare recent_count integer;
begin
 select count(*) into recent_count from public.comentarios c
 where c.user_id=new.user_id and c.criado_em>now()-interval '10 minutes';
 if recent_count>=3 then raise exception 'Limite de comentários atingido. Aguarde alguns minutos.'; end if;
 return new;
end; $$;
revoke all on function private.enforce_comment_rate_limit() from public,anon,authenticated;
drop trigger if exists enforce_comment_rate_limit on public.comentarios;
create trigger enforce_comment_rate_limit before insert on public.comentarios
for each row execute function private.enforce_comment_rate_limit();

create or replace function private.set_comment_author_name()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_name text;
begin
 select coalesce(nullif(trim(p.apelido),''),'Cinéfilo') into v_name
 from public.perfis p where p.user_id=new.user_id;
 new.nome:=coalesce(v_name,'Cinéfilo');
 return new;
end; $$;
revoke all on function private.set_comment_author_name() from public,anon,authenticated;
drop trigger if exists set_comment_author_name on public.comentarios;
create trigger set_comment_author_name before insert on public.comentarios
for each row execute function private.set_comment_author_name();

create table if not exists public.quiz_perguntas (
 id text primary key, pergunta text not null, opcoes jsonb not null,
 resposta smallint not null check (resposta between 0 and 2)
);
alter table public.quiz_perguntas enable row level security;
revoke all on public.quiz_perguntas from anon,authenticated;
insert into public.quiz_perguntas(id,pergunta,opcoes,resposta) values
 ('espaco','Qual destes filmes se passa principalmente no espaço?','["Interestelar","O Poderoso Chefão","Parasita"]'::jsonb,0),
 ('titanic','Quem dirigiu Titanic (1997)?','["Christopher Nolan","James Cameron","Steven Spielberg"]'::jsonb,1),
 ('panem','Qual é o planeta fictício de Jogos Vorazes?','["Duna","Pandora","Panem"]'::jsonb,2),
 ('vader','Em qual saga aparece o personagem Darth Vader?','["Star Wars","Matrix","Gladiador"]'::jsonb,0),
 ('pixar','Qual destes é um filme de animação da Pixar?','["Whiplash","Ratatouille","Coringa"]'::jsonb,1)
on conflict(id) do update set pergunta=excluded.pergunta,opcoes=excluded.opcoes,resposta=excluded.resposta;
create or replace view public.quiz_perguntas_public as select id,pergunta,opcoes from public.quiz_perguntas;
grant select on public.quiz_perguntas_public to anon,authenticated;

alter table public.pontuacoes_quiz add column if not exists pergunta_id text;
alter table public.pontuacoes_quiz alter column pergunta_id set not null;
create unique index if not exists quiz_one_answer_per_question on public.pontuacoes_quiz(user_id,pergunta_id);
drop policy if exists "Quiz: inserir própria pontuação" on public.pontuacoes_quiz;
drop policy if exists "Admins can delete quiz scores" on public.pontuacoes_quiz;
create policy "Admins can delete quiz scores" on public.pontuacoes_quiz for delete to authenticated using ((select private.is_admin()));
revoke insert,update on public.pontuacoes_quiz from anon,authenticated;
grant select on public.pontuacoes_quiz to anon,authenticated;
grant delete on public.pontuacoes_quiz to authenticated;

create or replace function public.responder_quiz(p_pergunta_id text,p_resposta smallint)
returns table(correta boolean,pontos integer,ja_respondida boolean)
language plpgsql security definer set search_path = ''
as $$
declare v_user uuid:=auth.uid(); v_resposta smallint; v_apelido text; v_rows integer;
begin
 if v_user is null then raise exception 'Entre na sua conta para registrar sua resposta.'; end if;
 select q.resposta into v_resposta from public.quiz_perguntas q where q.id=p_pergunta_id;
 if not found then raise exception 'Pergunta inválida.'; end if;
 if p_resposta is null or p_resposta<0 or p_resposta>2 then raise exception 'Resposta inválida.'; end if;
 select coalesce(nullif(trim(p.apelido),''),'Cinéfilo') into v_apelido from public.perfis p where p.user_id=v_user;
 insert into public.pontuacoes_quiz(user_id,apelido,pontos,pergunta_id)
 values(v_user,coalesce(v_apelido,'Cinéfilo'),case when p_resposta=v_resposta then 1 else 0 end,p_pergunta_id)
 on conflict(user_id,pergunta_id) do nothing;
 get diagnostics v_rows=row_count;
 if v_rows=0 then return query select false,0,true;
 else return query select p_resposta=v_resposta,case when p_resposta=v_resposta then 1 else 0 end,false; end if;
end; $$;
revoke all on function public.responder_quiz(text,smallint) from public,anon;
grant execute on function public.responder_quiz(text,smallint) to authenticated;

create or replace view public.ranking_quiz with (security_invoker=true) as
select user_id,max(apelido) as apelido,sum(pontos)::bigint as pontos,count(*)::bigint as respostas
from public.pontuacoes_quiz group by user_id;
grant select on public.ranking_quiz to anon,authenticated;

create or replace view public.ranking_usuarios_avaliacoes with (security_invoker=true) as
select p.user_id,coalesce(nullif(trim(p.apelido),''),'Cinéfilo') as apelido,count(a.filme_slug)::bigint as total_avaliacoes
from public.perfis p join public.avaliacoes_usuarios a on a.user_id=p.user_id group by p.user_id,p.apelido;
grant select on public.ranking_usuarios_avaliacoes to anon,authenticated;

create table if not exists private.help_rate_limits (
 fingerprint text primary key, window_started_at timestamptz not null default now(),
 request_count integer not null default 0
);
alter table private.help_rate_limits enable row level security;
revoke all on private.help_rate_limits from public,anon,authenticated;
create or replace function public.consume_help_rate_limit(p_fingerprint text)
returns boolean language plpgsql security definer set search_path = ''
as $$
declare v_count integer;
begin
 if p_fingerprint is null or length(p_fingerprint)<32 or length(p_fingerprint)>128 then return false; end if;
 insert into private.help_rate_limits(fingerprint,window_started_at,request_count) values(p_fingerprint,now(),1)
 on conflict(fingerprint) do update set
 request_count=case when private.help_rate_limits.window_started_at<now()-interval '10 minutes' then 1 else private.help_rate_limits.request_count+1 end,
 window_started_at=case when private.help_rate_limits.window_started_at<now()-interval '10 minutes' then now() else private.help_rate_limits.window_started_at end
 returning request_count into v_count;
 return v_count<=12;
end; $$;
revoke all on function public.consume_help_rate_limit(text) from public,anon,authenticated;
grant execute on function public.consume_help_rate_limit(text) to service_role;

-- Daily attempt key prevents repeated points for the same question on the same day.
create or replace function public.responder_quiz(p_pergunta_id text,p_resposta smallint)
returns table(correta boolean,pontos integer,ja_respondida boolean)
language plpgsql security definer set search_path = ''
as $$
declare
 v_user uuid:=auth.uid(); v_resposta smallint; v_apelido text; v_rows integer;
 v_attempt_id text:=p_pergunta_id||':'||to_char(current_date,'YYYY-MM-DD');
begin
 if v_user is null then raise exception 'Entre na sua conta para registrar sua resposta.'; end if;
 select q.resposta into v_resposta from public.quiz_perguntas q where q.id=p_pergunta_id;
 if not found then raise exception 'Pergunta inválida.'; end if;
 if p_resposta is null or p_resposta<0 or p_resposta>2 then raise exception 'Resposta inválida.'; end if;
 select coalesce(nullif(trim(p.apelido),''),'Cinéfilo') into v_apelido from public.perfis p where p.user_id=v_user;
 insert into public.pontuacoes_quiz(user_id,apelido,pontos,pergunta_id)
 values(v_user,coalesce(v_apelido,'Cinéfilo'),case when p_resposta=v_resposta then 1 else 0 end,v_attempt_id)
 on conflict(user_id,pergunta_id) do nothing;
 get diagnostics v_rows=row_count;
 if v_rows=0 then return query select false,0,true;
 else return query select p_resposta=v_resposta,case when p_resposta=v_resposta then 1 else 0 end,false; end if;
end; $$;


-- Final quiz hardening: only question text/options are readable via column grants.
drop view if exists public.quiz_perguntas_public;
drop policy if exists "Quiz questions are publicly readable" on public.quiz_perguntas;
create policy "Quiz questions are publicly readable" on public.quiz_perguntas
  for select to anon,authenticated using (true);
revoke all on public.quiz_perguntas from anon,authenticated;
grant select (id,pergunta,opcoes) on public.quiz_perguntas to anon,authenticated;
drop policy if exists "No direct access to help rate limits" on private.help_rate_limits;
create policy "No direct access to help rate limits" on private.help_rate_limits
  for all to public using (false) with check (false);

create or replace function private.submit_quiz_answer(p_pergunta_id text,p_resposta smallint)
returns table(correta boolean,pontos integer,ja_respondida boolean)
language plpgsql security definer set search_path = ''
as $$
declare
 v_user uuid:=auth.uid(); v_resposta smallint; v_apelido text; v_rows integer;
 v_attempt_id text:=p_pergunta_id||':'||to_char(current_date,'YYYY-MM-DD');
begin
 if v_user is null then raise exception 'Entre na sua conta para registrar sua resposta.'; end if;
 select q.resposta into v_resposta from public.quiz_perguntas q where q.id=p_pergunta_id;
 if not found then raise exception 'Pergunta inválida.'; end if;
 if p_resposta is null or p_resposta<0 or p_resposta>2 then raise exception 'Resposta inválida.'; end if;
 select coalesce(nullif(trim(p.apelido),''),'Cinéfilo') into v_apelido from public.perfis p where p.user_id=v_user;
 insert into public.pontuacoes_quiz(user_id,apelido,pontos,pergunta_id)
 values(v_user,coalesce(v_apelido,'Cinéfilo'),case when p_resposta=v_resposta then 1 else 0 end,v_attempt_id)
 on conflict(user_id,pergunta_id) do nothing;
 get diagnostics v_rows=row_count;
 if v_rows=0 then return query select false,0,true;
 else return query select p_resposta=v_resposta,case when p_resposta=v_resposta then 1 else 0 end,false; end if;
end; $$;
revoke all on function private.submit_quiz_answer(text,smallint) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.submit_quiz_answer(text,smallint) to authenticated;
create or replace function public.responder_quiz(p_pergunta_id text,p_resposta smallint)
returns table(correta boolean,pontos integer,ja_respondida boolean)
language sql security invoker set search_path = ''
as $$ select * from private.submit_quiz_answer(p_pergunta_id,p_resposta); $$;
revoke all on function public.responder_quiz(text,smallint) from public,anon;
grant execute on function public.responder_quiz(text,smallint) to authenticated;


-- Least-privilege table grants. Keep this block after all table/view creation.
revoke all on all tables in schema public from anon,authenticated;
grant select on public.avaliacoes,public.comentarios,public.perfis,
 public.avaliacoes_usuarios,public.votos_batalha,public.pontuacoes_quiz,
 public.ranking_filmes,public.ranking_quiz,public.ranking_batalha,
 public.ranking_usuarios_avaliacoes,public.ranking_notas_usuarios
 to anon,authenticated;
grant insert,update,delete on public.avaliacoes to authenticated;
grant insert,delete on public.comentarios to authenticated;
grant insert,update on public.perfis to authenticated;
grant select,insert,delete on public.listas_filmes,public.minhas_listas to authenticated;
grant insert on public.votos_batalha to authenticated;
grant delete on public.pontuacoes_quiz to authenticated;
grant insert,update on public.avaliacoes_usuarios to authenticated;
grant select,insert,delete on public.solicitacoes_amizade to authenticated;
grant update(status) on public.solicitacoes_amizade to authenticated;
grant select,insert on public.mensagens to authenticated;
grant select on public.user_roles to authenticated;
grant select(id,pergunta,opcoes) on public.quiz_perguntas to anon,authenticated;
drop policy if exists "Ratings: delete own" on public.avaliacoes;
drop policy if exists "Admins can delete ratings" on public.avaliacoes;
create policy "Ratings: owner or admin delete" on public.avaliacoes for delete to authenticated
 using ((select auth.uid())=user_id or (select private.is_admin()));
drop policy if exists "Comments: delete own" on public.comentarios;
drop policy if exists "Admins can delete comments" on public.comentarios;
create policy "Comments: owner or admin delete" on public.comentarios for delete to authenticated
 using ((select auth.uid())=user_id or (select private.is_admin()));
create index if not exists comentarios_user_created_idx on public.comentarios(user_id,criado_em desc);
