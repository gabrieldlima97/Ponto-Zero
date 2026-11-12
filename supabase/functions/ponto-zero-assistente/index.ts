import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const allowedOrigins = new Set([
  "https://ponto-zero.github.io",
  "http://localhost:5500",
  "http://127.0.0.1:5500",
]);
const corsHeaders = {
  "Access-Control-Allow-Origin": "https://ponto-zero.github.io",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function json(data: unknown, status = 200, origin?: string) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      ...(origin && allowedOrigins.has(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
function extractText(payload: any): string {
  if (typeof payload.output_text === "string" && payload.output_text.trim()) return payload.output_text.trim();
  const chunks: string[] = [];
  for (const item of payload.output ?? []) {
    if (item.type !== "message") continue;
    for (const part of item.content ?? []) {
      if (part.type === "output_text" && typeof part.text === "string") chunks.push(part.text);
    }
  }
  return chunks.join("\n").trim();
}
Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin") ?? "";
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { ...corsHeaders, ...(allowedOrigins.has(origin) ? { "Access-Control-Allow-Origin": origin } : {}) } });
  }
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405, origin);
  if (origin && !allowedOrigins.has(origin)) return json({ error: "Origem não autorizada." }, 403, origin);
  const contentLength = Number(req.headers.get("content-length") || 0);
  if (contentLength > 20000) return json({ error: "Mensagem muito grande. Reduza o texto e tente novamente." }, 413, origin);

  // Rate limit persistente no banco, compartilhado entre instâncias da Edge Function.
  const forwarded = req.headers.get("x-forwarded-for")?.split(",").map(v => v.trim()).filter(Boolean) || [];
  const ip = req.headers.get("cf-connecting-ip")?.trim()
    || req.headers.get("x-real-ip")?.trim()
    || forwarded[forwarded.length - 1]
    || "unknown";
  const rateUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!rateUrl || !serviceKey) {
    console.error("Persistent help rate limit is not configured.");
    return json({ error: "O atendimento está temporariamente indisponível. Tente novamente mais tarde." }, 503, origin);
  }
  try {
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode("ponto-zero-help-v1|" + ip));
    const fingerprint = Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("");
    const limitResponse = await fetch(`${rateUrl}/rest/v1/rpc/consume_help_rate_limit`, {
      method: "POST",
      headers: {
        "apikey": serviceKey,
        "Authorization": `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_fingerprint: fingerprint }),
    });
    if (!limitResponse.ok) {
      console.error("Persistent help rate limit failed:", limitResponse.status);
      return json({ error: "O atendimento está temporariamente indisponível. Tente novamente mais tarde." }, 503, origin);
    }
    const allowed = await limitResponse.json();
    if (allowed !== true) return json({ error: "Você enviou muitas mensagens. Aguarde alguns minutos e tente novamente." }, 429, origin);
  } catch (error) {
    console.error("Help rate limit error:", error instanceof Error ? error.message : "unknown");
    return json({ error: "O atendimento está temporariamente indisponível. Tente novamente mais tarde." }, 503, origin);
  }

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    console.error("OPENAI_API_KEY secret is missing.");
    return json({ error: "O atendimento está temporariamente indisponível. A administração precisa revisar a configuração da IA." }, 503, origin);
  }
  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Pedido inválido." }, 400, origin); }
  if (!Array.isArray(body.messages) || body.messages.length < 1 || body.messages.length > 12) return json({ error: "Envie uma conversa com até 12 mensagens." }, 400, origin);
  const messages = body.messages.map((m: any) => ({
    role: m?.role === "assistant" ? "assistant" : "user",
    content: typeof m?.content === "string" ? m.content.trim().slice(0, 1200) : "",
  })).filter((m: any) => m.content.length > 0);
  if (!messages.length || messages[messages.length - 1].role !== "user") return json({ error: "Escreva uma pergunta para continuar." }, 400, origin);
  const instructions = "Você é o assistente inteligente do Ponto Zero. Responda perguntas de qualquer assunto, não apenas sobre o site. Use português brasileiro por padrão, com simpatia, clareza e objetividade; acompanhe o idioma do visitante quando fizer sentido. Responda diretamente a dúvidas gerais, explique conceitos, ajude com estudos, tecnologia, cultura, entretenimento e tarefas cotidianas. Se não souber algo ou a pergunta exigir informação atual que você não pode verificar, diga isso claramente e não invente fatos, fontes ou links. Para temas médicos, jurídicos ou financeiros, ofereça informação geral e recomende confirmação com profissional qualificado; em situações urgentes, oriente procurar ajuda local imediata.\n\nQuando a pergunta for sobre o Ponto Zero, use estas informações:\n- Comunidade: criação e acesso à conta.\n- Filmes: catálogo, busca e páginas individuais com sinopse, trailer e avaliações.\n- Avaliações por estrelas (1 a 5) e comentários exigem que o visitante esteja conectado; cada conta pode manter uma avaliação por filme e alterá-la.\n- A nota pessoal de 0 a 10 fica salva no perfil público.\n- O quiz exige login e permite uma resposta por pergunta por dia; a pontuação é validada no servidor.\n- Amigos: pesquisar perfis pelo apelido, enviar convite, aceitar ou recusar pedidos.\n- Chat privado: só funciona entre pessoas cuja amizade foi aceita.\n- Onde assistir: mostra plataformas/serviços quando disponíveis; catálogo e disponibilidade podem mudar.\n- Ranking: mostra os usuários que mais avaliaram filmes.\nRegras:\n1. Dê instruções em passos curtos e pergunte apenas o detalhe necessário quando faltar informação.\n2. Não diga que acessou contas, viu dados privados, corrigiu algo ou executou ações; você não tem acesso às contas nem ferramentas administrativas.\n3. Nunca peça senhas, códigos de confirmação, tokens, chaves de API ou dados bancários.\n4. Se houver erro no site, peça a página, a ação feita e o texto exato do erro, sem dados sensíveis.\n5. Não invente funções do Ponto Zero, links, políticas ou garantias. Se não souber, admita.\n6. Links internos conhecidos: index.html, filmes.html, comunidade.html, social.html, ranking.html, ajuda.html.\n7. Seja acolhedor e evite respostas excessivamente longas.";
  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-6-luna",
        instructions,
        input: messages.map((m: any) => ({ role: m.role, content: m.content })),
        max_output_tokens: 650,
        store: false,
      }),
      signal: AbortSignal.timeout(25000),
    });
    const payload = await response.json();
    if (!response.ok) {
      console.error("OpenAI request failed:", response.status, payload?.error?.type || "unknown");
      return json({ error: response.status === 429 ? "O atendimento está ocupado neste momento. Aguarde um pouco e tente novamente." : "Não consegui responder agora. Tente novamente em instantes." }, response.status === 429 ? 429 : 502, origin);
    }
    const answer = extractText(payload);
    if (!answer) return json({ error: "Não recebi uma resposta. Tente reformular sua pergunta." }, 502, origin);
    return json({ reply: answer }, 200, origin);
  } catch (error) {
    console.error("Support assistant error:", error instanceof Error ? error.message : "unknown");
    return json({ error: "O atendimento demorou para responder. Tente novamente." }, 504, origin);
  }
});