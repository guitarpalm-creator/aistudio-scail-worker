"""
Hace que psutil (y por lo tanto ComfyUI) vea la RAM REAL del contenedor de RunPod.

Sin esto, psutil lee la RAM de toda la máquina (cientos de GB), ComfyUI cree que le sobra memoria,
no libera nada y el contenedor (límite ~46 GB en A40/A6000) muere por OOM con videos largos.
Python carga este archivo solo al arrancar (sitecustomize). Si algo falla, no cambia nada.
"""


def _leer(ruta):
    try:
        with open(ruta) as f:
            return f.read().strip()
    except OSError:
        return None


def _limite_cgroup():
    valor = _leer("/sys/fs/cgroup/memory.max")                       # cgroup v2
    if valor and valor != "max":
        return int(valor)
    valor = _leer("/sys/fs/cgroup/memory/memory.limit_in_bytes")     # cgroup v1
    if valor and int(valor) < (1 << 60):
        return int(valor)
    return None


def _uso_cgroup():
    valor = _leer("/sys/fs/cgroup/memory.current") or _leer("/sys/fs/cgroup/memory/memory.usage_in_bytes")
    if valor is None:
        return None
    uso = int(valor)
    estadisticas = _leer("/sys/fs/cgroup/memory.stat") or _leer("/sys/fs/cgroup/memory/memory.stat") or ""
    for linea in estadisticas.splitlines():
        clave, _, numero = linea.partition(" ")
        if clave in ("inactive_file", "total_inactive_file"):     # caché de disco que el kernel puede soltar
            uso -= int(numero)
            break
    return max(0, uso)


try:
    import psutil

    _original = psutil.virtual_memory

    def virtual_memory():
        vm = _original()
        limite = _limite_cgroup()
        if not limite or limite >= vm.total:
            return vm
        uso = _uso_cgroup()
        disponible = max(0, limite - uso) if uso is not None else min(vm.available, limite)
        disponible = min(disponible, vm.available)
        usado = limite - disponible
        return vm._replace(total=limite, available=disponible, used=usado, free=disponible,
                           percent=round(100.0 * usado / limite, 1))

    psutil.virtual_memory = virtual_memory
except Exception:
    pass
