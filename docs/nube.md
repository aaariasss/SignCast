# Infraestructura en la nube

Los datos se comparten en una carpeta de **Google Drive** y el modelo se distribuye con **Firebase** (plan Spark, sin costo). Los datos y modelos **no van al repo**.

Se eligió Drive en lugar de Cloud Storage porque Google Cloud pide tarjeta y sus créditos vencen a los 90 días, y los datos del proyecto son pequeños (unos 35 MB el dataset público, más las grabaciones del equipo).

## Resumen

| Concepto | Valor |
|---|---|
| Datos | [Carpeta de Drive](https://drive.google.com/drive/folders/1Qy4yopwbec2VXHipS9UW5C6UOsja2yuw?usp=drive_link) (acceso restringido al equipo) |
| Proyecto de Firebase | SignCast (`signcast-01`), plan Spark |
| Entrenamiento | Colab |

## Carpeta de Drive

```
SignCast-datos/
├── raw/
│   ├── equipo/        grabaciones del equipo (grabar.py)
│   └── publico.zip    dataset público de CICESE convertido
├── procesado/         alfabeto_publico.npz y datos listos para entrenar
└── modelos/           modelos entrenados y .tflite
```

Es la misma estructura que `data/` en el repo (`data/raw`, `data/procesado`), más `modelos/`.

**Accesos:** Aarian, Carlos y Valeria son Editores de la carpeta y del proyecto de Firebase. Nadie más tiene acceso.

**Subir:** arrastrar los archivos a la carpeta correspondiente. Las carpetas con muchos archivos se comprimen antes:

```
Compress-Archive -Path data\raw\publico -DestinationPath $HOME\Desktop\publico.zip
```

**Bajar:** descargar desde Drive y dejar en `data/` con la misma estructura. El `publico.zip` se descomprime dentro de `data/raw/`.

## Entrenamiento

Se entrena en **Colab**: no tiene costo y los datos y modelos (LSTM y MLP) son pequeños. Flujo: montar o subir los datos desde Drive, instalar `ml/requirements.txt`, correr `python -m signcast.entrenar` y guardar el modelo en `modelos/` de Drive.

## Firebase

- Proyecto en plan **Spark**. Si pide pasar a Blaze o ingresar una tarjeta, no aceptar y avisar al equipo.
- La app web se publica en Firebase Hosting; ver [publicar_web.md](publicar_web.md).
