# =====================================================================
#  Worker "Transferir movimiento · varios personajes" para aistudiolibre.com
#  SCAIL-2 (Zhipu AI, licencia MIT) sobre Wan 2.1 14B, en fp8.
#    - modo ANIMAR: los personajes de la foto hacen los movimientos del video
#    - modo REEMPLAZAR: los personajes de la foto reemplazan a las personas del video
#  SAM 3.1 encuentra a cada persona y las empareja de izquierda a derecha (hasta 6).
#
#  Base: la misma imagen oficial de RunPod que el worker de Wan Animate (ComfyUI 0.34.0).
#  Esa versión de ComfyUI YA TRAE los nodos de SCAIL-2 y SAM3: no hace falta ningún nodo extra.
#  Todos los modelos son PÚBLICOS en Hugging Face: no hace falta token ni volumen.
#  Quedan DENTRO de la imagen (~28 GB de modelos).
# =====================================================================
FROM runpod/worker-comfyui:5.10.0-base-cuda12.8.1

# ---------------------------------------------------------------------
# v1.1.0: ComfyUI calcula la RAM libre con psutil, que ve la RAM de TODA la máquina
# (cientos de GB) y no el límite del contenedor (~46 GB en A40/A6000). Por eso nunca
# liberaba memoria y los videos de 15 s morían por OOM. sitecustomize.py le hace ver
# a psutil el límite real del contenedor (Python lo carga solo al arrancar).
# ---------------------------------------------------------------------
COPY sitecustomize.py /tmp/sitecustomize.py
RUN /opt/venv/bin/python -c "import site, shutil; d = site.getsitepackages()[0]; shutil.copy('/tmp/sitecustomize.py', d); print('sitecustomize en', d)" \
 && /opt/venv/bin/python -c "import psutil; print('psutil OK, RAM vista:', round(psutil.virtual_memory().total / 2**30, 1), 'GB')"

WORKDIR /comfyui/models
RUN mkdir -p diffusion_models loras text_encoders clip_vision vae checkpoints

# Modelo principal SCAIL-2 14B en fp8 (17.7 GB)
RUN wget -nv --tries=5 -O diffusion_models/wan2.1_14B_SCAIL_2_fp8_scaled.safetensors \
    "https://huggingface.co/Comfy-Org/SCAIL-2/resolve/main/diffusion_models/wan2.1_14B_SCAIL_2_fp8_scaled.safetensors"

# Codificador de texto umt5 (6.7 GB)
RUN wget -nv --tries=5 -O text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# LoRAs: DPO de SCAIL-2 (manos, boca y ojos) y velocidad lightx2v (6 pasos)
RUN wget -nv --tries=5 -O loras/wan2.1_SCAIL_2_DPO_lora_bf16.safetensors \
    "https://huggingface.co/Comfy-Org/SCAIL-2/resolve/main/loras/wan2.1_SCAIL_2_DPO_lora_bf16.safetensors" \
 && wget -nv --tries=5 -O loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

# CLIP Vision, VAE y SAM 3.1 (detecta y sigue a cada persona)
RUN wget -nv --tries=5 -O clip_vision/clip_vision_h.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
 && wget -nv --tries=5 -O vae/wan_2.1_vae.safetensors \
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
 && wget -nv --tries=5 -O checkpoints/sam3.1_multiplex_fp16.safetensors \
    "https://huggingface.co/Comfy-Org/sam3.1/resolve/main/checkpoints/sam3.1_multiplex_fp16.safetensors"

# Comprobación: lista lo descargado (se ve en el log de construcción)
RUN ls -lh diffusion_models loras text_encoders clip_vision vae checkpoints

# ---------------------------------------------------------------------
# Prueba de arranque: si ComfyUI no carga o faltan los nodos de SCAIL-2/SAM3,
# la construcción FALLA aquí (mejor enterarse ahora que cuando un usuario pida un video)
# ---------------------------------------------------------------------
WORKDIR /comfyui
RUN timeout 600 python main.py --quick-test-for-ci --cpu 2>&1 | tee /tmp/arranque.log \
 && ! grep -q "IMPORT FAILED" /tmp/arranque.log \
 && grep -q "nodes_scail.py" comfy_extras/../nodes.py \
 && echo "ComfyUI arrancó y cargó los nodos de SCAIL-2 y SAM3"

WORKDIR /
