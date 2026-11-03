// Edge Function: admin-users
//
// Crear, editar y desactivar cuentas exige la clave secreta de Supabase, que
// nunca puede viajar al cliente. Esta función comprueba que quien llama es un
// administrador activo y solo entonces usa el cliente privilegiado.
//
// Acciones:
//   create     { email, name, surname, password?, role?, job_role_id?,
//                active?, opener?, working_days? }
//   update     { id, email, name, surname, password?, role?, job_role_id?,
//                active?, opener?, working_days? }
//   setActive  { id, active }

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type Payload = {
  action?: 'create' | 'update' | 'setActive';
  id?: number;
  email?: string;
  name?: string;
  surname?: string;
  password?: string;
  role?: 'admin' | 'employee';
  job_role_id?: number | null;
  active?: boolean;
  opener?: boolean;
  working_days?: string;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/** Clave secreta nueva (sb_secret_...) con fallback a la legacy. */
function secretKey(): string {
  const raw = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (raw) {
    const keys = JSON.parse(raw) as Record<string, string>;
    const first = keys['default'] ?? Object.values(keys)[0];
    if (first) return first;
  }
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!legacy) throw new Error('Falta la clave secreta de Supabase');
  return legacy;
}

function profileValues(payload: Payload): Record<string, unknown> {
  const values: Record<string, unknown> = {};
  if (payload.name !== undefined) values.name = payload.name.trim();
  if (payload.surname !== undefined) values.surname = payload.surname.trim();
  if (payload.email !== undefined) values.email = payload.email.trim().toLowerCase();
  if (payload.role !== undefined) values.role = payload.role;
  if (payload.job_role_id !== undefined) values.job_role_id = payload.job_role_id;
  if (payload.active !== undefined) values.active = payload.active;
  if (payload.opener !== undefined) values.opener = payload.opener;
  if (payload.working_days !== undefined) values.working_days = payload.working_days;
  return values;
}

async function requireAdmin(
  req: Request,
  url: string,
): Promise<{ admin: SupabaseClient; userId: string } | Response> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'No autorizado.' }, 401);

  const anonKey =
    Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (!anonKey) return json({ error: 'Falta la clave pública.' }, 500);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return json({ error: 'Sesión no válida.' }, 401);
  }

  const admin = createClient(url, secretKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('role, active')
    .eq('auth_id', authData.user.id)
    .maybeSingle();

  if (profileError) {
    return json({ error: profileError.message }, 500);
  }
  if (!profile || !profile.active || profile.role !== 'admin') {
    return json({ error: 'Solo un administrador puede gestionar usuarios.' }, 403);
  }

  return { admin, userId: authData.user.id };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Método no permitido.' }, 405);
  }

  const url = Deno.env.get('SUPABASE_URL');
  if (!url) return json({ error: 'Falta SUPABASE_URL.' }, 500);

  const auth = await requireAdmin(req, url);
  if (auth instanceof Response) return auth;
  const { admin } = auth;

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Cuerpo JSON no válido.' }, 400);
  }

  try {
    switch (payload.action) {
      case 'create': {
        const email = payload.email?.trim().toLowerCase();
        if (!email) return json({ error: 'El email es obligatorio.' }, 400);
        if (!payload.name?.trim()) {
          return json({ error: 'El nombre es obligatorio.' }, 400);
        }

        const password = payload.password?.trim() || 'favorita';
        if (password.length < 6) {
          return json(
            { error: 'La contraseña debe tener al menos 6 caracteres.' },
            400,
          );
        }

        const { data: created, error: createError } =
          await admin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: {
              name: payload.name.trim(),
              surname: payload.surname?.trim() ?? '',
            },
          });

        if (createError || !created.user) {
          return json(
            { error: createError?.message ?? 'No se pudo crear la cuenta.' },
            400,
          );
        }

        const { error: updateError } = await admin
          .from('profiles')
          .update({
            ...profileValues(payload),
            name: payload.name.trim(),
            surname: payload.surname?.trim() ?? '',
            email,
            role: payload.role ?? 'employee',
            active: payload.active ?? true,
            must_change_password: true,
          })
          .eq('auth_id', created.user.id);

        if (updateError) {
          await admin.auth.admin.deleteUser(created.user.id);
          return json({ error: updateError.message }, 400);
        }

        const { data: profile } = await admin
          .from('profiles')
          .select('id')
          .eq('auth_id', created.user.id)
          .maybeSingle();

        return json({ id: profile?.id ?? null });
      }

      case 'update': {
        if (!payload.id) return json({ error: 'Falta el id.' }, 400);

        const { data: current, error: findError } = await admin
          .from('profiles')
          .select('auth_id')
          .eq('id', payload.id)
          .maybeSingle();

        if (findError) return json({ error: findError.message }, 400);
        if (!current) return json({ error: 'Usuario no encontrado.' }, 404);

        const authChanges: Record<string, unknown> = {};
        if (payload.email !== undefined) {
          authChanges.email = payload.email.trim().toLowerCase();
          authChanges.email_confirm = true;
        }
        if (payload.password) {
          if (payload.password.length < 6) {
            return json(
              { error: 'La contraseña debe tener al menos 6 caracteres.' },
              400,
            );
          }
          authChanges.password = payload.password;
        }
        if (payload.name !== undefined || payload.surname !== undefined) {
          authChanges.user_metadata = {
            name: payload.name?.trim() ?? '',
            surname: payload.surname?.trim() ?? '',
          };
        }

        if (Object.keys(authChanges).length > 0) {
          type AdminAttributes = Parameters<
            typeof admin.auth.admin.updateUserById
          >[1];
          const { error: authError } = await admin.auth.admin.updateUserById(
            current.auth_id,
            authChanges as AdminAttributes,
          );
          if (authError) return json({ error: authError.message }, 400);
        }

        const values = profileValues(payload);
        if (Object.keys(values).length > 0) {
          const { error: updateError } = await admin
            .from('profiles')
            .update(values)
            .eq('id', payload.id);
          if (updateError) return json({ error: updateError.message }, 400);
        }

        return json({ id: payload.id });
      }

      case 'setActive': {
        if (!payload.id || payload.active === undefined) {
          return json({ error: 'Faltan id o active.' }, 400);
        }

        const { data: current, error: findError } = await admin
          .from('profiles')
          .select('auth_id')
          .eq('id', payload.id)
          .maybeSingle();

        if (findError) return json({ error: findError.message }, 400);
        if (!current) return json({ error: 'Usuario no encontrado.' }, 404);

        const { error: updateError } = await admin
          .from('profiles')
          .update({ active: payload.active })
          .eq('id', payload.id);

        if (updateError) return json({ error: updateError.message }, 400);

        // Al desactivar, se bloquea también la cuenta de Auth para que no
        // pueda seguir refrescando la sesión.
        await admin.auth.admin.updateUserById(current.auth_id, {
          ban_duration: payload.active ? 'none' : '876000h',
        });

        return json({ id: payload.id });
      }

      default:
        return json({ error: 'Acción no reconocida.' }, 400);
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});
