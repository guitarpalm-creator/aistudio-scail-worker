# aistudio-scail-worker

Worker serverless de RunPod para **Transferir movimiento · varios personajes** en aistudiolibre.com.

- **Modelo:** SCAIL-2 (Zhipu AI, licencia MIT) sobre Wan 2.1 14B en fp8, con LoRA DPO y LoRA de velocidad lightx2v (6 pasos).
- **Modo animar:** los personajes de la foto hacen los movimientos de las personas del video; se queda el fondo de la foto.
- **Modo reemplazar:** los personajes de la foto reemplazan a las personas del video; se queda el fondo del video.
- **Automático:** SAM 3.1 encuentra a cada persona en el video y a cada personaje en la foto, y los empareja de izquierda a derecha (hasta 6). No hay que marcar puntos.

La base es `runpod/worker-comfyui:5.10.0-base-cuda12.8.1` (ComfyUI 0.34.0), que ya trae los nodos de SCAIL-2 y SAM3. Los modelos son públicos en Hugging Face y quedan dentro de la imagen, así que no hace falta token ni network volume.

RunPod vuelve a construir la imagen cada vez que se publica una **release** nueva en GitHub.

## Versiones
- **v1.0.0:** primera versión.
- **v1.1.0:** `sitecustomize.py` hace que ComfyUI vea el límite real de RAM del contenedor (antes veía la RAM de toda la máquina, no liberaba memoria y los videos de 15 s morían por OOM).

## Entrada
Formato estándar de worker-comfyui:

```json
{"input": {"workflow": {...}, "images": [
  {"name": "referencia.jpg", "image": "<base64>"},
  {"name": "movimiento.mp4", "image": "<base64>"}
]}}
```

El workflow lo arma `scail_workflow.py` en el servidor de la web. El video tiene que llegar al tamaño final (múltiplos de 32), a **16 fps** y con pista de audio.
