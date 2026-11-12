# ponto-zero-assistente

Edge Function da central de ajuda do Ponto Zero.

## Secrets e configuração

- Cadastre `OPENAI_API_KEY` em Supabase → Edge Functions → Secrets.
- A função usa as variáveis padrão do Supabase `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` para consumir o limite persistente de chamadas.
- `verify_jwt` permanece desativado porque o assistente é público; a função aplica CORS, valida método e tamanho, e usa limite persistente por IP com hash.
- A função depende de `public.consume_help_rate_limit(text)`, criada no arquivo `supabase-setup.sql`.

Não coloque chaves no repositório. Faça deploy com `verify_jwt=false` somente enquanto a própria função mantiver essas verificações.
