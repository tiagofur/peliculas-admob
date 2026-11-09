-- "Olvidé mi contraseña": un código de 6 dígitos por correo, válido 15 minutos.
-- Se guarda solo su hash; cada solicitud nueva invalida las anteriores.
CREATE TABLE password_resets (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    code_hash  bytea       NOT NULL,           -- sha256(user_id || ':' || code)
    attempts   int         NOT NULL DEFAULT 0, -- intentos fallidos; a partir de 5 se anula
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    used_at    timestamptz
);
CREATE INDEX password_resets_user_id_idx ON password_resets (user_id);
