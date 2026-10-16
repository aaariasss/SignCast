# Frases del MVP

Frases que se graban (issue #11) y se usan para probar el constructor de frases
(`ml/signcast/frases.py` y su versión en Dart, issue #18).

Reglas de escritura en comandos y glosas: mayúsculas, sin ñ y sin acentos
(`BANO`, `MANANA`, `COMPANERO`).

Comando para grabar una frase (10 repeticiones por persona, una sola toma de 5 s):

```
python -m signcast.grabar --persona <tu_nombre> --frase "YO NO ENTENDER" --repeticiones 10
```

## Frases a grabar (13)

| # | Glosas | Traducción esperada | Notas |
|---|--------|---------------------|-------|
| 1 | YO NO ENTENDER | No entiendo. | |
| 2 | ENTENDER NO | No entiendo. | Orden invertido; el `NO` es el segundo. |
| 3 | REPETIR POR-FAVOR | ¿Puede repetir, por favor? | |
| 4 | AYUDAR YO POR-FAVOR | ¿Me puede ayudar, por favor? | |
| 5 | YO PODER IR BANO | ¿Puedo ir al baño? | |
| 6 | TAREA CUANDO | ¿Cuándo es la tarea? | |
| 7 | BANO DONDE | ¿Dónde está el baño? | |
| 8 | MANANA EXAMEN | Mañana hay examen. | |
| 9 | YO TENER PREGUNTA | Tengo una pregunta. | |
| 10 | MAESTRO REPETIR | El maestro repite. | |
| 11 | MANANA YO IR CLASE | Mañana voy a la clase. | |
| 12 | HOLA YO A N A | Hola. Soy Ana. | Las letras `A N A` se deletrean dentro de la frase. |
| 13 | HOLA HOLA _REPOSO YO NO ENTENDER GRACIAS | Hola. No entiendo. Gracias. | Prueba repetidos y pausa: `HOLA` repetido cuenta una vez y `_REPOSO` separa frases. Se hace una seña tras otra, con una pausa de manos abajo en medio. |

## Casos de una sola seña (solo prueba, no se graban como frase)

Estos casos ya están en `ml/tests/test_frases.py`; se prueban con las señas
sueltas de la sección 1 y no necesitan grabarse como frase.

| Glosas | Traducción esperada |
|--------|---------------------|
| SI | Sí. |
| GRACIAS | Gracias. |


