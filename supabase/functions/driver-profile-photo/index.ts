import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const imageTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const { driver_id, access_code, image_base64, content_type } = await request.json();
    if (
      typeof driver_id !== 'string' ||
      typeof access_code !== 'string' ||
      typeof image_base64 !== 'string' ||
      !imageTypes.has(content_type)
    ) {
      return jsonResponse({ error: 'Invalid upload request' }, 400);
    }

    if (image_base64.length > 7_000_000) {
      return jsonResponse({ error: 'Image exceeds the 5 MB limit' }, 413);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ error: 'Upload service is not configured' }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: driver, error: driverError } = await admin
      .from('employees')
      .select('id')
      .eq('id', driver_id)
      .eq('access_code', access_code)
      .eq('role', 'driver')
      .maybeSingle();

    if (driverError || !driver) {
      return jsonResponse({ error: 'Invalid driver access code' }, 401);
    }

    const binary = atob(image_base64);
    const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    if (bytes.byteLength > 5 * 1024 * 1024 || !hasValidImageSignature(bytes, content_type)) {
      return jsonResponse({ error: 'Invalid image or image exceeds the 5 MB limit' }, 400);
    }

    const extension = content_type === 'image/png'
      ? 'png'
      : content_type === 'image/webp'
        ? 'webp'
        : 'jpg';
    const objectPath = `drivers/${driver.id}/avatar.${extension}`;
    const { error: uploadError } = await admin.storage
      .from('profile-photos')
      .upload(objectPath, bytes, {
        contentType: content_type,
        cacheControl: '0',
        upsert: true,
      });

    if (uploadError) {
      return jsonResponse({ error: 'Unable to store profile photo' }, 500);
    }

    const avatarUrl = `${admin.storage.from('profile-photos').getPublicUrl(objectPath).data.publicUrl}?v=${Date.now()}`;
    const { error: updateError } = await admin
      .from('employees')
      .update({ profile_image_url: avatarUrl })
      .eq('id', driver.id);

    if (updateError) {
      return jsonResponse({ error: 'Unable to update driver profile' }, 500);
    }

    return jsonResponse({ avatar_url: avatarUrl }, 200);
  } catch {
    return jsonResponse({ error: 'Invalid upload request' }, 400);
  }
});

function hasValidImageSignature(bytes: Uint8Array, contentType: string): boolean {
  if (contentType === 'image/jpeg') {
    return bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  }
  if (contentType === 'image/png') {
    return bytes.length > 8 && bytes[0] === 0x89 && bytes[1] === 0x50 &&
      bytes[2] === 0x4e && bytes[3] === 0x47;
  }
  return contentType === 'image/webp' && bytes.length > 12 &&
    String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF' &&
    String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP';
}

function jsonResponse(body: Record<string, string>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}