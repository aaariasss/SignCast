# Datos de SignCast

Esta carpeta **no se sube al repo** (solo este README). Los archivos generados se comparten en una carpeta de Google Drive (ver [docs/nube.md](../docs/nube.md)).

## Dataset público de LSM (CICESE)

López-Nava et al., 2026 · 27 letras, 40 personas · CC-BY 4.0. El dataset solo trae imágenes y videos; los puntos clave se extrajeron con MediaPipe usando `ml/signcast/convertir_publico.py`.

| Conjunto | Letras | Fuente |
|---|---|---|
| Estáticas (imágenes) | 21 | https://doi.org/10.5281/zenodo.10067509 |
| Dinámicas (videos, vista frontal) | J, K, Ñ, Q, X, Z | https://doi.org/10.5281/zenodo.14689869 |

### Dónde están los archivos

En la [carpeta de Drive del equipo](https://drive.google.com/drive/folders/1Qy4yopwbec2VXHipS9UW5C6UOsja2yuw?usp=drive_link) (acceso restringido):

- `procesado/alfabeto_publico.npz`: letras estáticas (21).
- `raw/publico.zip`: letras dinámicas (6), un `.npz` por video. Se descomprime dentro de `data/raw/`.

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

Estáticas: hasta 3000 imágenes por letra y por división (entrenamiento y prueba), elegidas al azar; "sin mano detectada" son imágenes donde MediaPipe no encontró la mano. Dinámicas: videos de la vista frontal.

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

## Grabaciones del equipo

Cada persona grabó con `grabar.py` las 27 señas, las 27 letras, el reposo y las 13 frases (entre 825 y 851 tomas). Las carpetas van en `data/raw/equipo/<persona>/` y se comparten por Drive (`raw/equipo/`). La tabla se regenera con `python -m signcast.contar_equipo --salida ../data/README.md` (desde `ml/`).

<!-- equipo:inicio -->
| Clase | aarian | carlo | valeria | Total |
|---|---:|---:|---:|---:|
| A | 5 | 5 | 5 | 15 |
| B | 5 | 5 | 5 | 15 |
| C | 5 | 5 | 5 | 15 |
| D | 10 | 5 | 5 | 20 |
| E | 5 | 5 | 5 | 15 |
| F | 5 | 5 | 5 | 15 |
| G | 5 | 5 | 5 | 15 |
| H | 5 | 5 | 5 | 15 |
| I | 5 | 5 | 5 | 15 |
| L | 5 | 5 | 5 | 15 |
| M | 5 | 5 | 5 | 15 |
| N | 5 | 5 | 5 | 15 |
| O | 5 | 5 | 5 | 15 |
| P | 10 | 5 | 5 | 20 |
| R | 5 | 5 | 5 | 15 |
| S | 10 | 5 | 5 | 20 |
| T | 5 | 5 | 5 | 15 |
| U | 5 | 5 | 5 | 15 |
| V | 5 | 5 | 5 | 15 |
| W | 5 | 5 | 5 | 15 |
| Y | 5 | 5 | 5 | 15 |
| J | 5 | 5 | 5 | 15 |
| K | 10 | 5 | 5 | 20 |
| Ñ | 5 | 5 | 5 | 15 |
| Q | 5 | 5 | 5 | 15 |
| X | 5 | 5 | 5 | 15 |
| Z | 10 | 5 | 5 | 20 |
| _REPOSO | 20 | 20 | 20 | 60 |
| HOLA | 20 | 20 | 20 | 60 |
| ADIOS | 20 | 20 | 20 | 60 |
| GRACIAS | 21 | 20 | 20 | 61 |
| POR-FAVOR | 20 | 20 | 20 | 60 |
| SI | 20 | 20 | 20 | 60 |
| NO | 20 | 20 | 20 | 60 |
| YO | 20 | 20 | 20 | 60 |
| TU | 20 | 20 | 20 | 60 |
| MAESTRO | 20 | 20 | 20 | 60 |
| COMPANERO | 20 | 20 | 20 | 60 |
| CLASE | 20 | 20 | 20 | 60 |
| TAREA | 20 | 20 | 20 | 60 |
| EXAMEN | 20 | 20 | 20 | 60 |
| PREGUNTA | 20 | 20 | 20 | 60 |
| ENTENDER | 20 | 20 | 20 | 60 |
| REPETIR | 20 | 20 | 20 | 60 |
| AYUDAR | 20 | 20 | 20 | 60 |
| PODER | 20 | 20 | 20 | 60 |
| IR | 20 | 20 | 20 | 60 |
| TENER | 20 | 20 | 20 | 60 |
| BANO | 20 | 20 | 20 | 60 |
| QUE | 20 | 20 | 20 | 60 |
| DONDE | 20 | 20 | 20 | 60 |
| CUANDO | 20 | 20 | 20 | 60 |
| COMO | 20 | 20 | 20 | 60 |
| HOY | 20 | 20 | 20 | 60 |
| MANANA | 20 | 20 | 20 | 60 |
| AYUDAR YO POR-FAVOR | 10 | 10 | 10 | 30 |
| BANO DONDE | 10 | 10 | 10 | 30 |
| ENTENDER NO | 10 | 10 | 10 | 30 |
| HOLA HOLA _REPOSO YO NO ENTENDER GRACIAS | 10 | 14 | 10 | 34 |
| HOLA YO A N A | 10 | 10 | 10 | 30 |
| MAESTRO REPETIR | 10 | 10 | 10 | 30 |
| MANANA EXAMEN | 10 | 10 | 10 | 30 |
| MANANA YO IR CLASE | 10 | 10 | 10 | 30 |
| REPETIR POR-FAVOR | 10 | 10 | 10 | 30 |
| TAREA CUANDO | 10 | 10 | 10 | 30 |
| YO NO ENTENDER | 10 | 10 | 10 | 30 |
| YO PODER IR BANO | 10 | 10 | 10 | 30 |
| YO TENER PREGUNTA | 10 | 10 | 10 | 30 |
| **Total** | **851** | **829** | **825** | **2505** |
| FPS medio | 22 | 12 | 10 | |
<!-- equipo:fin -->

Los FPS de la grabación cambian entre personas. Cada toma se remuestrea a 30 cuadros, así que el modelo ve la misma longitud en todas.

## División por persona

- **Prueba:** `valeria`, que queda fuera del entrenamiento (`--persona-prueba valeria`). Se eligió por haber grabado a ~10 FPS, parecido al navegador del iPhone.
- **Entrenamiento (señas):** `aarian`, `carlo` y las 20 personas del dataset público, con aumento de datos solo aquí.
- **Validación (señas):** 15 % de las tomas de entrenamiento, por clase. Con tres personas, validar por persona dejaría fuera la mayoría de las señas.
- **Alfabeto:** la validación es por persona (3 personas del dataset público); la prueba es `valeria`.
