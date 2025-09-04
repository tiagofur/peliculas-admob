import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.0.0"

serve(async (req) => {
  try {
    const { actionType, payload } = await req.json()

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
    )

    switch (actionType) {
      case "ADD_FAVORITE": {
        const { error } = await supabase.from("user_favorites").upsert(payload)
        if (error) throw error
        break
      }
      // TODO: Implement other action types
      default:
        throw new Error("Invalid action type")
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    )
  }
})
