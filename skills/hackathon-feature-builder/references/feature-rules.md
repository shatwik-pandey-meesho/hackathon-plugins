# Feature Rules

Build features as a complete vertical slice:

1. Data shape in SQLite.
2. Backend route or handler.
3. Frontend screen, form, list, chart, or button.
4. Basic validation and error display.
5. One manual verification path.

## Defaults

- Use REST JSON APIs.
- Use `/api/...` route prefixes on the backend.
- From the frontend, call the backend with same-origin relative paths like `fetch('/api/...')`.
  Never hardcode a host or port (no `http://localhost:8090`); nginx (in the image) and the dev
  server (locally) proxy `/api` to the backend, so the app works on any deployed domain.
- Use parameterized SQL only.
- Return clear JSON errors: `{ "error": "message" }`.
- Keep form fields few and obvious.
- Add seed data only when it helps the participant see the feature quickly.

## Avoid

- New databases or services.
- Complex auth providers.
- Payment integrations.
- WebSockets or background workers unless required by the app idea.
- Large UI libraries unless already present.
