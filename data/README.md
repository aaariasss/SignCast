# Datos de SignCast

Esta carpeta **no se sube al repo** (solo este README). Los archivos generados viven en Cloud Storage.

## Dataset público de LSM (CICESE)

López-Nava et al., 2026 · 27 letras, 40 personas · CC-BY 4.0. El dataset solo trae imágenes y videos; los puntos clave se extrajeron con MediaPipe usando `ml/signcast/convertir_publico.py`.

| Conjunto | Letras | Fuente |
|---|---|---|
| Estáticas (imágenes) | 21 | https://doi.org/10.5281/zenodo.10067509 |
| Dinámicas (videos, vista frontal) | J, K, Ñ, Q, X, Z | https://doi.org/10.5281/zenodo.14689869 |

### Dónde están los archivos

- Cloud Storage: `gs://<BUCKET>/<RUTA>/` (completar al subir)
  - `procesado/alfabeto_publico.npz` (estáticas)
  - `raw/publico/` (dinámicas, un `.npz` por video)

### Cómo regenerarlos

Desde `ml/`:

```
pip install -r requirements.txt
python -m signcast.descargar_modelos
python -m signcast.convertir_publico estaticas --origen <carpeta_estaticas>
python -m signcast.convertir_publico dinamicas --origen <carpeta_dinamicas>
python -m signcast.contar_publico --salida ../data/README.md
```

### Conteo por letra

<!-- conteo:inicio -->
| Letra | Tipo | Ejemplos | Sin mano detectada |
|---|---|---:|---:|
| A | estática | 4399 | 24 |
| B | estática | 4308 | 30 |
| C | estática | 4182 | 118 |
| D | estática | 4322 | 84 |
| E | estática | 4247 | 120 |
| F | estática | 4372 | 23 |
| G | estática | 4172 | 57 |
| H | estática | 4246 | 54 |
| I | estática | 4283 | 52 |
| L | estática | 4350 | 11 |
| M | estática | 4201 | 55 |
| N | estática | 4263 | 29 |
| O | estática | 4310 | 81 |
| P | estática | 4238 | 62 |
| R | estática | 4256 | 47 |
| S | estática | 4197 | 76 |
| T | estática | 4261 | 40 |
| U | estática | 4223 | 18 |
| V | estática | 4236 | 18 |
| W | estática | 4263 | 25 |
| Y | estática | 4194 | 72 |
| J | dinámica | 102 | 0 |
| K | dinámica | 105 | 0 |
| Ñ | dinámica | 107 | 0 |
| Q | dinámica | 101 | 0 |
| X | dinámica | 104 | 0 |
| Z | dinámica | 102 | 0 |
| **Total** | | **90144** | **1096** |
<!-- conteo:fin -->
