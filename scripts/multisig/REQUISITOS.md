# Requisitos para ejecutar create_multisig.sh

## ✅ Solo se necesita Linera CLI instalado

```bash
# Verificar instalación
linera --version
```

## 🔧 Instalación de Linera CLI

Visita: https://linera.dev/developers/getting_started/index.html

## 💾 No requiere configuración del repositorio

Este script es **autocontenido** y **no depende de archivos del repositorio**:

- ❌ No requiere configuración previa
- ❌ No requiere archivos del repo
- ❌ No requiere variables de entorno del repo
- ✅ Funciona después de clonar el repo
- ✅ Crea su propio directorio temporal

## 🖥️ Dependencias del sistema

Las siguientes herramientas estánndar vienen con macOS/Linux:

| Herramienta | Uso | Verificación |
|--------------|-----|-------------|
| `bash` | Ejecutar script | `bash --version` |
| `grep` | Parsear output | `grep --version` |
| `awk` | Extraer campos | `awk --version` |
| `python3` | Medir tiempo (macOS) | `python3 --version` |

## 🚀 Uso

```bash
# Desde cualquier ubicación
bash /ruta/al/repo/scripts/multisig/create_multisig.sh

# O desde el directorio del repo
cd /Users/alfredolopez/Documents/GitHub/PalmeraDAO/linera.dev/scripts/multisig
./create_multisig.sh
```
