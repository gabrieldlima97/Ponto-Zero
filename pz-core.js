/* Ponto Zero — núcleo compartilhado
 * Mantém uma única instância do Supabase e centraliza o armazenamento da lista.
 */
(function (window) {
  "use strict";

  const CONFIG = Object.freeze({
    supabaseUrl: "https://fkeayqbvmifdzsiskqno.supabase.co",
    publishableKey: "sb_publishable_6MqEvatKcbWY3gfwDAglBA_jftIs8ty",
    favoritesKey: "pz-favoritos",
    profileKey: "pz-perfil"
  });

  let client = null;

  function getSupabase() {
    if (client) return client;
    if (!window.supabase || typeof window.supabase.createClient !== "function") {
      return null;
    }
    client = window.supabase.createClient(CONFIG.supabaseUrl, CONFIG.publishableKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      },
      global: { headers: { "x-application-name": "ponto-zero" } }
    });
    return client;
  }

  function readJSON(key, fallback) {
    try {
      const value = window.localStorage.getItem(key);
      return value ? JSON.parse(value) : fallback;
    } catch (error) {
      console.warn("[Ponto Zero] Não foi possível ler o armazenamento local.", error);
      return fallback;
    }
  }

  function writeJSON(key, value) {
    try {
      window.localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (error) {
      console.warn("[Ponto Zero] Não foi possível salvar no armazenamento local.", error);
      return false;
    }
  }

  function readFavorites() {
    const value = readJSON(CONFIG.favoritesKey, []);
    return Array.isArray(value) ? [...new Set(value.filter(x => typeof x === "string" && x.trim()))] : [];
  }

  function writeFavorites(ids) {
    return writeJSON(CONFIG.favoritesKey, [...new Set((ids || []).filter(x => typeof x === "string" && x.trim()))]);
  }

  async function syncFavorites() {
    const supabase = getSupabase();
    if (!supabase) return { synced: false, reason: "client-unavailable", ids: readFavorites() };

    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    if (sessionError) throw sessionError;
    if (!session?.user) return { synced: false, reason: "signed-out", ids: readFavorites() };

    const localIds = readFavorites();
    if (localIds.length) {
      const rows = localIds.map(filme_slug => ({ user_id: session.user.id, filme_slug }));
      const { error } = await supabase.from("listas_filmes")
        .upsert(rows, { onConflict: "user_id,filme_slug", ignoreDuplicates: true });
      if (error) throw error;
    }

    const { data, error } = await supabase.from("listas_filmes")
      .select("filme_slug")
      .eq("user_id", session.user.id)
      .order("criado_em", { ascending: false });
    if (error) throw error;

    const ids = (data || []).map(row => row.filme_slug).filter(Boolean);
    writeFavorites(ids);
    return { synced: true, ids };
  }

  async function toggleFavorite(slug) {
    if (!slug || typeof slug !== "string") throw new TypeError("Identificador de filme inválido.");
    const ids = readFavorites();
    const removing = ids.includes(slug);
    const next = removing ? ids.filter(id => id !== slug) : [...ids, slug];
    const supabase = getSupabase();

    if (supabase) {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      if (sessionError) throw sessionError;
      if (session?.user) {
        const query = supabase.from("listas_filmes");
        const result = removing
          ? await query.delete().eq("user_id", session.user.id).eq("filme_slug", slug)
          : await query.insert({ user_id: session.user.id, filme_slug: slug });
        if (result.error) throw result.error;
      }
    }

    writeFavorites(next);
    return { saved: !removing, ids: next };
  }

  function clearPrivateLocalData() {
    try {
      window.localStorage.removeItem(CONFIG.favoritesKey);
      window.localStorage.removeItem(CONFIG.profileKey);
    } catch (error) {
      console.warn("[Ponto Zero] Não foi possível limpar os dados locais.", error);
    }
  }

  window.PZ = Object.freeze({
    config: CONFIG,
    supabase: getSupabase(),
    getSupabase,
    readJSON,
    writeJSON,
    readFavorites,
    writeFavorites,
    syncFavorites,
    toggleFavorite,
    clearPrivateLocalData
  });
})(window);
