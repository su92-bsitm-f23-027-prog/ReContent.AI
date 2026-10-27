from django.contrib import admin
from django.http import HttpResponse, JsonResponse
from django.urls import include, path


def health_check(request):
    return JsonResponse({"status": "ok"})


def api_home(request):
    return HttpResponse("""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ReContent AI · Backend</title><style>
:root{color-scheme:light;--ink:#211d39;--muted:#68657b;--violet:#6557d9;--line:#e7e5f1;--bg:#f7f6fc}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font:16px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif;color:var(--ink)}
main{max-width:980px;margin:40px auto;padding:0 22px}.hero{padding:36px;border-radius:24px;background:linear-gradient(125deg,#292545,#6557d9);color:white}
.brand{font-weight:750;font-size:18px}.hero h1{font-size:clamp(30px,5vw,46px);line-height:1.12;margin:28px 0 10px}.hero p{max-width:680px;color:#e6e2ff;margin:0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:16px;margin:20px 0}.card{background:white;border:1px solid var(--line);border-radius:16px;padding:22px}
h2{font-size:18px;margin:0 0 10px}.muted{color:var(--muted);font-size:14px}.step{display:flex;gap:12px;align-items:flex-start;margin:12px 0}.num{flex:none;width:27px;height:27px;border-radius:9px;background:#eeecff;color:var(--violet);text-align:center;font-weight:700}
a{color:var(--violet);font-weight:650;text-decoration:none}a:hover{text-decoration:underline}code{font:13px ui-monospace,Consolas,monospace;background:#f1eff8;padding:3px 6px;border-radius:5px;overflow-wrap:anywhere}
.routes{display:grid;grid-template-columns:1fr auto;gap:9px 16px;align-items:center}.footer{color:var(--muted);font-size:13px;text-align:center;padding:14px}
@media(max-width:560px){main{margin:18px auto}.hero{padding:26px}.card{padding:18px}.routes{grid-template-columns:1fr}}
</style></head><body><main>
<header class="hero"><div class="brand">✦ ReContent AI <span style="opacity:.72">Backend</span></div>
<h1>Your project API is running.</h1><p>This Django service handles accounts, source material, generated content, and scheduling. The Flutter app calls these routes over HTTP.</p></header>
<section class="grid"><article class="card"><h2>How the pieces work</h2>
<div class="step"><span class="num">1</span><div><b>Flutter frontend</b><div class="muted">Collects user input and displays content.</div></div></div>
<div class="step"><span class="num">2</span><div><b>Authentication</b><div class="muted">Django issues API tokens; Google sign-in is verified through Firebase.</div></div></div>
<div class="step"><span class="num">3</span><div><b>Django REST API</b><div class="muted">Validates requests and reads or writes project data.</div></div></div>
<div class="step"><span class="num">4</span><div><b>Database</b><div class="muted">Stores users, sources, content, and scheduled posts.</div></div></div>
</article><article class="card"><h2>Useful pages</h2>
<p><a href="/health/">Health check</a><br><span class="muted">Confirms the server responds with JSON.</span></p>
<p><a href="/admin/">Django admin</a><br><span class="muted">Administrative interface for authorized staff.</span></p>
<p><b>Authentication API</b><br><span class="muted">API routes return JSON; some require an account.</span></p>
</article></section>
<section class="card"><h2>Main API routes</h2><p class="muted">These are API endpoints, not browser pages. The frontend sends requests to them.</p>
<div class="routes"><code>POST /api/auth/register/</code><span class="muted">Create an account</span>
<code>POST /api/auth/login/</code><span class="muted">Email and password sign-in</span>
<code>POST /api/auth/firebase/</code><span class="muted">Verify Firebase Google sign-in</span>
<code>GET /api/auth/me/</code><span class="muted">Read the signed-in profile</span>
<code>/api/sources/ · /api/content/ · /api/schedules/</code><span class="muted">Project features</span></div></section>
<p class="footer">Local development server · Keep this terminal open while using the app.</p>
</main></body></html>""")

urlpatterns = [
    path("", api_home, name="api-home"),
    path("health/", health_check, name="health-check"),
    path("admin/", admin.site.urls),
    path("api/auth/", include("apps.accounts.urls")),
    path("api/", include("apps.sources.urls")),
    path("api/", include("apps.generation.urls")),
    path("api/", include("apps.scheduling.urls")),
    path("api/integrations/", include("apps.integrations.urls")),
]

