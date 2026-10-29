# Resultados

<!-- aumento-alfabeto:inicio -->
## Aumento de datos: Alfabeto

Prueba: valeria. Media ± desviación de 3 semillas.

| Copias de aumento | Exactitud | F1 macro | Cumple meta |
|---:|---:|---:|:---:|
| 0 | 0.917 ± 0.045 | 0.916 ± 0.044 | sí |
| 3 | 0.949 ± 0.022 | 0.945 ± 0.026 | sí |

Clases con más cambio de F1 entre 0 y 3 copias:

- S: 0.97 → 0.54
- C: 0.75 → 1.00
- I: 0.69 → 0.88
- T: 0.94 → 0.76
- Y: 0.71 → 0.89

Mejor: 3 copias.
<!-- aumento-alfabeto:fin -->

<!-- aumento-senas:inicio -->
## Aumento de datos: Señas (lstm)

Prueba: valeria. Media ± desviación de 3 semillas.

| Copias de aumento | Exactitud | F1 macro | Cumple meta |
|---:|---:|---:|:---:|
| 0 | 0.428 ± 0.024 | 0.384 ± 0.032 | no |
| 3 | 0.532 ± 0.017 | 0.487 ± 0.020 | no |

Clases con más cambio de F1 entre 0 y 3 copias:

- PODER: 0.28 → 0.80
- SI: 0.13 → 0.51
- Z: 0.00 → 0.35
- CLASE: 0.34 → 0.64
- NO: 0.18 → 0.41

Mejor: 3 copias.
<!-- aumento-senas:fin -->


