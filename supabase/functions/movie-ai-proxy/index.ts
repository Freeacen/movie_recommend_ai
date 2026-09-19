// ==============================================================================
// CineAI - Supabase Edge Function: Movie AI Proxy & Key Rotation Pool
// Model: llama-3.3-70b-versatile via Groq API
// Feature: Round-robin multi-key pool + Graceful PostgreSQL template degradation
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ------------------------------------------------------------------------------
// Groq Key Pool Manager (Round-Robin with Automatic Fallback on 429)
// ------------------------------------------------------------------------------
class GroqKeyPool {
  private keys: string[] = [];
  private currentIndex = 0;

  constructor() {
    const rawKeys = Deno.env.get("GROQ_API_KEYS") || Deno.env.get("GROQ_API_KEY") || "";
    this.keys = rawKeys
      .split(",")
      .map((k) => k.trim())
      .filter((k) => k.length > 10);
    console.log(`[GroqKeyPool] Initialized with ${this.keys.length} API key(s).`);
  }

  get hasKeys(): boolean {
    return this.keys.length > 0;
  }

  getNextKey(): string | null {
    if (!this.hasKeys) return null;
    const key = this.keys[this.currentIndex];
    this.currentIndex = (this.currentIndex + 1) % this.keys.length;
    return key;
  }

  get keyCount(): number {
    return this.keys.length;
  }
}

const keyPool = new GroqKeyPool();

// Supabase client for graceful degradation to cached_recommendations table
const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_ANON_KEY") || "";
const supabase = (supabaseUrl && supabaseServiceKey) 
  ? createClient(supabaseUrl, supabaseServiceKey) 
  : null;

// ------------------------------------------------------------------------------
// Helper: Call Groq API with automatic key rotation on rate limits
// ------------------------------------------------------------------------------
async function callGroqWithRotation(messages: any[], temperature = 0.3, responseJson = true): Promise<any> {
  const attempts = Math.max(1, keyPool.keyCount);

  for (let i = 0; i < attempts; i++) {
    const apiKey = keyPool.getNextKey();
    if (!apiKey) break;

    try {
      const payload: any = {
        model: "llama-3.3-70b-versatile",
        messages,
        temperature,
      };

      if (responseJson) {
        payload.response_format = { type: "json_object" };
      }

      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify(payload),
      });

      if (res.status === 200) {
        const data = await res.json();
        const content = data.choices[0]?.message?.content;
        return responseJson ? JSON.parse(content) : content;
      } else if (res.status === 429 || res.status === 503) {
        console.warn(`[GroqKeyPool] Key index hit status ${res.status}. Rotating to next key...`);
        continue; // Try next key in rotation pool
      } else {
        const errText = await res.text();
        console.error(`[Groq] API Error: ${res.status} - ${errText}`);
      }
    } catch (err) {
      console.warn(`[Groq] Request exception on key: ${err}. Trying next...`);
    }
  }

  throw new Error("All Groq API keys exhausted or unreachable.");
}

// ------------------------------------------------------------------------------
// Graceful Degradation: Fallback to PostgreSQL Cached Recommendation Templates
// ------------------------------------------------------------------------------
async function getCachedTemplateRecommendation(userPrompt: string, excludedIds: number[] = []): Promise<any> {
  if (!supabase) {
    return getHardcodedFallback();
  }

  try {
    const { data: recommendations, error } = await supabase
      .from("cached_recommendations")
      .select("*, cached_movies(*)")
      .limit(10);

    if (error || !recommendations || recommendations.length === 0) {
      return getHardcodedFallback();
    }

    // Filter out excluded / recently proposed movies
    const available = recommendations.filter((r: any) => !excludedIds.includes(r.movie_id));
    const chosen = available.length > 0 ? available[0] : recommendations[0];
    const movie = chosen.cached_movies;

    return {
      recommended_title: movie?.title || "Inception (Başlangıç)",
      movie_id: movie?.id || 27205,
      hook_genre: chosen.hook_genre,
      hook_mood: chosen.hook_mood,
      core_summary: chosen.core_summary,
      reason: `${chosen.hook_genre} ${chosen.core_summary}`,
      matching_aspects: chosen.target_aspects || ["ters köşe kurgu", "akıl yakan senaryo"],
      is_fallback: true,
      is_template: true,
    };
  } catch (_) {
    return getHardcodedFallback();
  }
}

function getHardcodedFallback() {
  return {
    recommended_title: "Inception (Başlangıç)",
    movie_id: 27205,
    hook_genre: "Zihin bükücü kurguları ve akıl oyunlarını seven bir sinemasever olarak",
    hook_mood: "Nefes kesici temposuyla",
    core_summary: "Bilinçaltının derinliklerine inen olağanüstü görsel dili ve paradokslarıyla tam sana göre.",
    reason: "Sinema zevkine ve akıl yakan kurgu tercihlerine tam uyan bir başyapıt: **Inception (Başlangıç)**!",
    matching_aspects: ["ters köşe kurgu", "akıl oyunları"],
    is_fallback: true,
    is_template: true,
  };
}

// ------------------------------------------------------------------------------
// Main Edge Function HTTP Handler
// ------------------------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, payload } = body;

    switch (action) {
      // 1. Personalized Movie Recommendation
      case "recommend": {
        const { prompt, tasteProfile, watchedTitles = [], excludedIds = [] } = payload;

        try {
          const systemPrompt = `Sen CineAI uygulamasının seçkin film danışmanısın. Modelin: Groq Llama 3.3.
Kullanıcının zevk profili: ${JSON.stringify(tasteProfile || {})}
Daha önce izlediği filmler: ${watchedTitles.join(", ")}
Kullanıcının anlık isteği: "${prompt}"

GÖREV:
Kullanıcının isteklerine en uygun bir film öner.
Daha önce izlediklerini tekrar önerme.
Mekanik olma, 2-3 samimi, sinematik ve tutkulu cümleyle açıkla.

SADECE şu JSON şemasında yanıt ver:
{
  "recommended_title": "Film Adı",
  "hook_genre": "Tür kancası cümlesi",
  "hook_mood": "Ruh hali kancası",
  "core_summary": "Filmin neden tam uyduğunu anlatan 2-3 cümle",
  "reason": "Tam tavsiye açıklaması",
  "matching_aspects": ["ters köşe", "etkileyici atmosfer"]
}`;

          const groqResult = await callGroqWithRotation(
            [
              { role: "system", content: systemPrompt },
              { role: "user", content: prompt },
            ],
            0.4,
            true
          );

          return new Response(
            JSON.stringify({ success: true, data: { ...groqResult, is_fallback: false } }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } catch (err) {
          console.warn("[recommend] Groq failed, degrading to cached template:", err);
          const templateResult = await getCachedTemplateRecommendation(prompt, excludedIds);
          return new Response(
            JSON.stringify({ success: true, data: templateResult }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      // 2. Multi-turn Conversational Movie Review (1.0 - 10.0 scale)
      case "chat_feedback": {
        const { movieTitle, conversationHistory = [], currentScore } = payload;

        try {
          const messages = [
            {
              role: "system",
              content: `Sen CineAI uygulamasının zeki ve tutkulu film eleştirmenisin.
Kullanıcı seninle "${movieTitle}" filmini izledikten sonra filmi değerlendirmek için sohbet ediyor.
Mevcut tahmini puan: ${currentScore ? currentScore + " / 10.0" : "Belirlenmedi"}

GÖREV:
1. "reply": Kullanıcının son mesajına samimi, sinemasever ve derin bir dille cevap ver (filmdeki detaylara, oyunculuğa değin).
2. "score": Kullanıcının beğeni derecesine göre 1.0 ile 10.0 arasında puan belirle (kullanıcı açıkça puan belirttiyse onu ata).
3. "liked_aspects": Beğendiği unsurları listele.
4. "disliked_aspects": Beğenmediği unsurları listele.
5. "summary": Kullanıcının film hakkındaki görüşlerini 2-3 cümleyle özetle.

SADECE geçerli bir JSON formatı döndür:
{
  "reply": "...",
  "score": 7.5,
  "liked_aspects": ["ters köşe kurgu"],
  "disliked_aspects": ["ağır orta tempo"],
  "summary": "..."
}`,
            },
            ...conversationHistory.map((m: any) => ({
              role: m.role === "assistant" ? "assistant" : "user",
              content: m.content || "",
            })),
          ];

          const result = await callGroqWithRotation(messages, 0.3, true);
          return new Response(
            JSON.stringify({ success: true, data: result }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } catch (err) {
          console.warn("[chat_feedback] Groq failed, returning local fallback structure:", err);
          return new Response(
            JSON.stringify({
              success: true,
              data: {
                reply: `Harika bir bakış açısı! ${movieTitle} hakkında paylaştığın detaylar zevk profiline işlendi. Başka bahsetmek istediğin bir sahne var mı?`,
                score: currentScore || 7.5,
                liked_aspects: ["atmosfer", "oyunculuk"],
                disliked_aspects: [],
                summary: `${movieTitle} hakkındaki değerlendirmelerin başarıyla kaydedildi.`,
                is_fallback: true,
              },
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      // 3. Identify Watched Movie from Natural Language
      case "identify_movie": {
        const { userPrompt } = payload;

        try {
          const messages = [
            {
              role: "system",
              content: `Kullanıcının şu mesajını analiz et: "${userPrompt}"
Kullanıcı izlediği bir filmden bahsediyor mu?
Cevabı SADECE JSON formatında ver:
{
  "movie_found": true,
  "title": "Filmin Adı",
  "release_date": "YYYY-MM-DD",
  "genres": "Bilim Kurgu, Gerilim",
  "overview": "2-3 cümlelik detaylı ve akıcı özet.",
  "vote_average": 8.0,
  "comment": "Bu film hakkında kullanıcıya 2-3 cümlelik sıcak, sinematik bir yorum yap ve değerlendirmek isteyip istemediğini sor."
}`,
            },
          ];

          const result = await callGroqWithRotation(messages, 0.2, true);
          return new Response(
            JSON.stringify({ success: true, data: result }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } catch (err) {
          return new Response(
            JSON.stringify({
              success: true,
              data: { movie_found: false, quota_exceeded: false, is_fallback: true },
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      default:
        return new Response(
          JSON.stringify({ success: false, error: `Unknown action: ${action}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
