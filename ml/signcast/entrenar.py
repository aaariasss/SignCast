from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from . import config as C
from .dataset import (aumentar_manos, aumentar_secuencias, cargar_alfabeto, cargar_senas,
                      dividir_por_persona, separar_validacion_por_toma)
from .muestras import etiquetas

META_EXACTITUD = 0.85
META_F1 = 0.80


def evaluar(modelo, X, y, clases: list[str]) -> dict:
    from sklearn.metrics import accuracy_score, confusion_matrix, f1_score

    pred = modelo.predict(X, verbose=0).argmax(axis=1)
    presentes = sorted(set(y.tolist()) | set(pred.tolist()))
    f1_clase = f1_score(y, pred, labels=presentes, average=None, zero_division=0)
    return {
        "exactitud": float(accuracy_score(y, pred)),
        "f1_macro": float(f1_score(y, pred, labels=sorted(set(y.tolist())), average="macro",
                                   zero_division=0)),
        "f1_por_clase": {clases[c]: round(float(f), 3) for c, f in zip(presentes, f1_clase)},
        "matriz": confusion_matrix(y, pred, labels=list(range(len(clases)))),
    }


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--tarea", choices=["senas", "alfabeto"], required=True)
    p.add_argument("--arquitectura", choices=["lstm", "transformer"], default="lstm",
                   help="Solo para --tarea senas")
    p.add_argument("--epocas", type=int, default=100)
    p.add_argument("--lote", type=int, default=32)
    p.add_argument("--copias-aumento", type=int, default=3)
    p.add_argument("--persona-prueba", nargs="*", help="Personas que van solo a prueba")
    p.add_argument("--semilla", type=int, default=42)
    p.add_argument("--salida", type=Path)
    a = p.parse_args()

    import keras

    from .modelos import ARQUITECTURAS, crear_mlp_alfabeto

    keras.utils.set_random_seed(a.semilla)
    rng = np.random.default_rng(a.semilla)

    if a.tarea == "senas":
        clases = etiquetas("senas")
        X, y, personas = cargar_senas(clases)
        crear = lambda: ARQUITECTURAS[a.arquitectura](len(clases))  # noqa: E731
        aumentar = aumentar_secuencias
        nombre = f"senas_{a.arquitectura}"
    else:
        clases = etiquetas("alfabeto")
        X, y, personas = cargar_alfabeto(clases)
        crear = lambda: crear_mlp_alfabeto(len(clases))  # noqa: E731
        aumentar = aumentar_manos
        nombre = "alfabeto_mlp"

    salida = a.salida or (C.DIR_MODELOS / nombre)
    salida.mkdir(parents=True, exist_ok=True)

    i_ent, i_val, i_pru = dividir_por_persona(personas, personas_prueba=a.persona_prueba,
                                              semilla=a.semilla)
    if a.tarea == "senas":
        # Con pocas personas, validar por persona dejaría clases fuera.
        i_ent, i_val = separar_validacion_por_toma(y, np.concatenate([i_ent, i_val]),
                                                   semilla=a.semilla)
    grupos = {k: sorted(set(personas[i].tolist())) for k, i in
              (("entrenamiento", i_ent), ("validacion", i_val), ("prueba", i_pru))}
    if a.tarea == "senas":
        grupos["validacion"] = f"15 % de las tomas de entrenamiento, por clase ({len(i_val)} tomas)"
    print(f"{len(X)} muestras, {len(clases)} clases, {len(set(personas.tolist()))} personas")
    for k, v in grupos.items():
        print(f"  {k}: {v}")
    if len(i_pru) == 0:
        print("No hay personas suficientes para un conjunto de prueba independiente. "
              "Las métricas de prueba no serán válidas hasta tener al menos 3 personas.")

    X_ent, y_ent = X[i_ent], y[i_ent]
    if a.copias_aumento > 0:
        X_ent = np.concatenate([X_ent] + [aumentar(X[i_ent], rng) for _ in range(a.copias_aumento)])
        y_ent = np.concatenate([y_ent] * (a.copias_aumento + 1))

    # Pesos por clase para que señas con pocas muestras no se ignoren
    conteo = np.bincount(y_ent, minlength=len(clases))
    pesos = {c: float(len(y_ent) / (len(clases) * n)) for c, n in enumerate(conteo) if n > 0}

    modelo = crear()
    modelo.compile(optimizer=keras.optimizers.Adam(1e-3),
                   loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    modelo.summary()

    hay_val = len(i_val) > 0
    monitor = "val_accuracy" if hay_val else "accuracy"
    modelo.fit(
        X_ent, y_ent,
        validation_data=(X[i_val], y[i_val]) if hay_val else None,
        epochs=a.epocas, batch_size=a.lote, class_weight=pesos, shuffle=True,
        callbacks=[
            keras.callbacks.EarlyStopping(monitor=monitor, patience=15, restore_best_weights=True),
            keras.callbacks.ReduceLROnPlateau(monitor=monitor, factor=0.5, patience=6),
        ],
        verbose=2,
    )

    modelo.save(salida / "modelo.keras")
    (salida / "etiquetas.txt").write_text("\n".join(clases) + "\n", encoding="utf-8")

    metricas = {"tarea": a.tarea, "modelo": nombre, "personas": grupos,
                "muestras": {"total": int(len(X)), "entrenamiento_con_aumento": int(len(X_ent))}}
    if len(i_pru):
        r = evaluar(modelo, X[i_pru], y[i_pru], clases)
        np.savetxt(salida / "matriz_confusion.csv", r.pop("matriz"), fmt="%d", delimiter=",",
                   header=",".join(clases), comments="")
        metricas["prueba"] = r
        metricas["cumple_meta"] = {"exactitud_85": r["exactitud"] >= META_EXACTITUD,
                                   "f1_080": r["f1_macro"] >= META_F1}
        print(f"\nPRUEBA ({', '.join(grupos['prueba'])}): exactitud {r['exactitud']:.3f} "
              f"| F1 macro {r['f1_macro']:.3f}")
        peores = sorted(r["f1_por_clase"].items(), key=lambda kv: kv[1])[:5]
        print("Clases más débiles:", ", ".join(f"{k} ({v})" for k, v in peores))

    (salida / "metricas.json").write_text(json.dumps(metricas, indent=2, ensure_ascii=False),
                                          encoding="utf-8")
    print(f"\nGuardado en {salida}")


if __name__ == "__main__":
    main()
