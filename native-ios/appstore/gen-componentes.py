#!/usr/bin/env python3
"""Genera el encabezado (3840x1646) y la imagen de resultados de búsqueda (1920x1280)
de la ficha de App Store, por idioma, con las capturas de appstore/screenshots/nuevas*.

  python3 appstore/gen-componentes.py            # es, en, pt-BR
  python3 appstore/gen-componentes.py en         # solo uno

Necesita Google Chrome (modo headless). Salida: appstore/componentes/*-sin-pro-*.png
"""
import subprocess, sys, tempfile, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent            # native-ios/appstore
ICON = ROOT.parent / "PeliculasNative/Assets.xcassets/AppIcon.appiconset/icon-default.png"
OUT = ROOT / "componentes"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

LANGS = {
    "es": dict(shots="nuevas", name="Películas: Series y Estrenos",
               l1="Descubre qué ver.", l2="Sigue tus series.",
               sub="Estrenos, Watchlist y “Siguiente” en un solo lugar. Sin anuncios."),
    "en": dict(shots="nuevas-en", name="Películas: Series &amp; Releases",
               l1="Find what to watch.", l2="Track your shows.",
               sub="New releases, watchlist and Up Next in one place. Ad-free."),
    "pt": dict(shots="nuevas-pt-BR", name="Películas: Séries e Estreias",
               l1="Descubra o que assistir.", l2="Acompanhe suas séries.",
               sub="Lançamentos, watchlist e “A seguir” em um só lugar. Sem anúncios."),
}

HEADER = """<!doctype html><meta charset=utf-8><style>
*{{box-sizing:border-box;margin:0}}
body{{width:3840px;height:1646px;overflow:hidden;font-family:-apple-system,"SF Pro Display","Helvetica Neue",sans-serif;color:#fff;position:relative;
background:radial-gradient(1400px 1000px at 85% 90%,rgba(120,60,30,.55),transparent 70%),linear-gradient(120deg,#0b0b10,#141214 60%,#1b1411)}}
.brand{{position:absolute;left:230px;top:400px;display:flex;align-items:center;gap:56px}}
.brand img{{width:210px;height:210px;border-radius:48px}} .brand span{{font-size:84px;font-weight:600;letter-spacing:-1px}}
h1{{position:absolute;left:230px;top:700px;font-size:{hf}px;line-height:1.03;font-weight:800;letter-spacing:-8px;white-space:nowrap}}
h1 b{{color:#ff6a3d;font-weight:800;display:block}}
p{{position:absolute;left:230px;top:1250px;width:1600px;font-size:84px;line-height:1.32;color:#c9c5c2}}
.ph{{position:absolute;width:560px;height:1215px;border-radius:95px;border:14px solid #1d1d20;overflow:hidden;box-shadow:0 60px 140px rgba(0,0,0,.7),0 0 0 3px #3a3a3f}}
.ph img{{width:100%;height:100%;object-fit:cover;object-position:top}}
.a{{left:2240px;top:330px;transform:rotate(-7deg)}} .b{{left:2720px;top:200px;z-index:3}} .c{{left:3180px;top:330px;transform:rotate(7deg)}}
</style>
<div class=brand><img src="{icon}"><span>{name}</span></div>
<h1>{l1}<b>{l2}</b></h1><p>{sub}</p>
<div class="ph a"><img src="{s}/02-detalle.png"></div><div class="ph c"><img src="{s}/04-biblioteca.png"></div><div class="ph b"><img src="{s}/01-inicio.png"></div>"""

SEARCH = """<!doctype html><meta charset=utf-8><style>
*{{box-sizing:border-box;margin:0}}
body{{width:1920px;height:1280px;overflow:hidden;font-family:-apple-system,"SF Pro Display","Helvetica Neue",sans-serif;color:#fff;position:relative;
background:radial-gradient(1200px 700px at 50% 100%,rgba(120,60,30,.45),transparent 70%),linear-gradient(180deg,#0e0e12,#17140f)}}
.brand{{position:absolute;top:70px;left:0;right:0;display:flex;justify-content:center;align-items:center;gap:22px}}
.brand img{{width:96px;height:96px;border-radius:24px}} .brand span{{font-size:44px;font-weight:600}}
h1{{position:absolute;top:195px;left:0;right:0;text-align:center;font-size:{fs}px;font-weight:800;letter-spacing:-3px;white-space:nowrap}} h1 b{{color:#ff6a3d}}
.ph{{position:absolute;width:380px;height:825px;border-radius:64px;border:9px solid #1d1d20;overflow:hidden;box-shadow:0 40px 90px rgba(0,0,0,.7),0 0 0 2px #3a3a3f}}
.ph img{{width:100%;height:100%;object-fit:cover;object-position:top}}
.a{{left:430px;top:455px;transform:rotate(-8deg)}} .b{{left:770px;top:395px;z-index:3;width:400px;height:868px}} .c{{left:1110px;top:455px;transform:rotate(8deg)}}
</style>
<div class=brand><img src="{icon}"><span>{name}</span></div>
<h1>{l1} <b>{l2}</b></h1>
<div class="ph a"><img src="{s}/02-detalle.png"></div><div class="ph c"><img src="{s}/05-buscar.png"></div><div class="ph b"><img src="{s}/01-inicio.png"></div>"""

def render(html, w, h, out):
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "p.html"; f.write_text(html, encoding="utf-8")
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=1", f"--window-size={w},{h}",
                        f"--screenshot={out}", f"file://{f}"], check=True, capture_output=True)

for lang in (sys.argv[1:] or LANGS):
    c = LANGS[lang]; s = (ROOT / "screenshots" / c["shots"]).as_uri()
    kw = dict(icon=ICON.as_uri(), s=s, **{k: c[k] for k in ("name", "l1", "l2", "sub")})
    render(HEADER.format(hf={"es": 230, "en": 205, "pt": 148}[lang], **kw), 3840, 1646, OUT / f"encabezado-sin-pro-3840x1646-{lang}.png")
    render(SEARCH.format(fs=84 if lang == "es" else 78, **kw), 1920, 1280, OUT / f"busqueda-sin-pro-1920x1280-{lang}.png")
    print("ok", lang)
